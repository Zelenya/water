defmodule Water.Seeds.DemoGarden do
  @moduledoc """
  Initialize the default household with demo data once.

  Household metadata and auth-linked members are kept in sync on reruns, but
  once any garden structure exists we leave sections and items untouched.
  """
  import Ecto.Query, warn: false

  alias Water.Households
  alias Water.Garden.{CareItem, Section}
  alias Water.Households.{Household, Member}
  alias Water.Repo

  @section_seeds [
    %{
      name: "Front of the House",
      items: [
        %{name: "Blueberry bed", type: :bed, watering_interval_days: 3},
        %{name: "Front flowers", type: :area, watering_interval_days: 10},
        %{name: "Front hedge", type: :area, watering_interval_days: 10}
      ]
    },
    %{
      name: "Veggie beds",
      items: [
        %{name: "West bed", type: :bed, watering_interval_days: 3},
        %{name: "East bed", type: :bed, watering_interval_days: 3},
        %{name: "Veggie babies", type: :bed, watering_interval_days: 2},
        %{name: "Bed raspberries", type: :bed, watering_interval_days: 7},
        %{name: "Pears", type: :plant, watering_interval_days: 7},
        %{name: "Native flower bed", type: :bed, watering_interval_days: 7}
      ]
    },
    %{
      name: "Back of the House",
      items: [
        %{name: "Long bed", type: :bed, watering_interval_days: 3},
        %{name: "Herb bed", type: :bed, watering_interval_days: 3},
        %{name: "Mulberry", type: :plant, watering_interval_days: 7},
        %{name: "Honey berries", type: :plant, watering_interval_days: 7},
        %{name: "Quince", type: :plant, watering_interval_days: 7},
        %{name: "Cherries", type: :plant, watering_interval_days: 7},
        %{name: "Peaches", type: :plant, watering_interval_days: 7}
      ]
    },
    %{
      name: "Nursery side",
      items: [
        %{name: "Nursery bed", type: :bed, watering_interval_days: 3},
        %{name: "Nursery pots", type: :bed, watering_interval_days: 3},
        %{name: "Raspberry and bushes", type: :plant, watering_interval_days: 10}
      ]
    },
    %{
      name: "Duck house",
      items: [
        %{name: "Current", type: :plant, watering_interval_days: 7},
        %{name: "Duck hedge", type: :area, watering_interval_days: 7},
        %{name: "Plum hedge", type: :area, watering_interval_days: 7}
      ]
    },
    %{
      name: "Downhill",
      items: [
        %{name: "Fruit trees", type: :area, watering_interval_days: 7},
        %{name: "Downhill bed", type: :bed, watering_interval_days: 3}
      ]
    }
  ]

  @type seed_result() :: %{
          household: Household.t(),
          members: [Member.t()],
          sections: [Section.t()],
          items: [CareItem.t()]
        }
  @seed_item_fields [:name, :type, :watering_interval_days, :position]

  @spec seed!() :: seed_result()
  def seed! do
    today = Date.utc_today()

    {:ok, household} = Households.bootstrap_default_household()

    household =
      household
      |> Household.changeset(%{
        name: "Water House",
        slug: "default",
        timezone: "America/Los_Angeles"
      })
      |> Repo.update!()

    # Note: this is tightly coupled with the logins and needs to be improved
    members = [
      upsert_member(household, %{name: "A", color: "#5B8DEF", active: true}),
      upsert_member(household, %{name: "J", color: "#F97316", active: true})
    ]

    if initialized?(household) do
      current_seed_result(household, members)
    else
      seed_initial_structure(household, members, today)
    end
  end

  @spec upsert_member(Household.t(), map()) :: Member.t()
  defp upsert_member(%Household{id: household_id} = household, attrs) do
    case find_member_by_name(household_id, Map.fetch!(attrs, :name)) do
      nil ->
        %Member{}
        |> Member.create_changeset(household, attrs)
        |> Repo.insert!()

      %Member{} = member ->
        member
        |> Member.update_changeset(attrs)
        |> Repo.update!()
    end
  end

  @spec find_member_by_name(Household.id(), String.t()) :: nil | Member.t()
  defp find_member_by_name(household_id, member_name) do
    normalized_name =
      member_name
      |> String.trim()
      |> String.downcase()

    from(member in Member,
      where:
        member.household_id == ^household_id and
          fragment("lower(btrim(?))", member.name) == ^normalized_name
    )
    |> Repo.one()
  end

  @spec initialized?(Household.t()) :: boolean()
  defp initialized?(%Household{id: household_id}) do
    Repo.exists?(from(section in Section, where: section.household_id == ^household_id)) ||
      Repo.exists?(from(care_item in CareItem, where: care_item.household_id == ^household_id))
  end

  @spec current_seed_result(Household.t(), [Member.t()]) :: seed_result()
  defp current_seed_result(%Household{} = household, members) do
    %{
      household: household,
      members: members,
      sections: list_sections(household),
      items: list_items(household)
    }
  end

  @spec seed_initial_structure(Household.t(), [Member.t()], Date.t()) :: seed_result()
  defp seed_initial_structure(%Household{} = household, members, %Date{} = today) do
    {sections, items, _item_seed_index} =
      Enum.reduce(Enum.with_index(@section_seeds), {[], [], 0}, fn {section_seed,
                                                                    section_position},
                                                                   {sections, items,
                                                                    item_seed_index} ->
        section =
          insert_section!(household, %{name: section_seed.name, position: section_position})

        {section_items, next_item_seed_index} =
          Enum.map_reduce(
            Enum.with_index(section_seed.items),
            item_seed_index,
            fn {item_seed, item_position}, seed_index ->
              attrs =
                item_seed
                |> seeded_item_attrs(today, item_position, seed_index)

              {insert_care_item!(household, section, attrs), seed_index + 1}
            end
          )

        {sections ++ [section], items ++ section_items, next_item_seed_index}
      end)

    %{
      household: household,
      members: members,
      sections: sections,
      items: items
    }
  end

  @spec list_sections(Household.t()) :: [Section.t()]
  defp list_sections(%Household{id: household_id}) do
    from(section in Section,
      where: section.household_id == ^household_id,
      order_by: [asc: section.position, asc: section.inserted_at]
    )
    |> Repo.all()
  end

  @spec list_items(Household.t()) :: [CareItem.t()]
  defp list_items(%Household{id: household_id}) do
    from(care_item in CareItem,
      where: care_item.household_id == ^household_id,
      order_by: [asc: care_item.section_id, asc: care_item.position, asc: care_item.inserted_at]
    )
    |> Repo.all()
  end

  @spec insert_section!(Household.t(), map()) :: Section.t()
  defp insert_section!(%Household{} = household, attrs) do
    %Section{}
    |> Section.create_changeset(household, attrs)
    |> Repo.insert!()
  end

  @spec seeded_item_attrs(map(), Date.t(), non_neg_integer(), non_neg_integer()) :: map()
  defp seeded_item_attrs(item_seed, %Date{} = today, item_position, seed_index) do
    item_seed
    |> seed_item_attrs(item_position)
    |> Map.merge(
      seed_schedule_attrs(today, Map.fetch!(item_seed, :watering_interval_days), seed_index)
    )
  end

  @spec seed_item_attrs(map()) :: map()
  defp seed_item_attrs(attrs) when is_map(attrs) do
    Map.take(attrs, @seed_item_fields)
  end

  @spec seed_item_attrs(map(), non_neg_integer()) :: map()
  defp seed_item_attrs(item_seed, item_position) when is_map(item_seed) do
    item_seed
    |> seed_item_attrs()
    |> Map.put(:position, item_position)
  end

  @spec insert_care_item!(Household.t(), Section.t(), map()) :: CareItem.t()
  defp insert_care_item!(%Household{} = household, %Section{} = section, attrs) do
    %CareItem{}
    |> CareItem.create_changeset(household, section, attrs)
    |> Repo.insert!()
  end

  @spec seed_schedule_attrs(Date.t(), pos_integer(), non_neg_integer()) :: map()
  defp seed_schedule_attrs(%Date{} = today, interval, seed_index) do
    case rem(seed_index, 5) do
      0 ->
        %{
          next_due_on: today,
          last_watered_on: Date.add(today, -interval),
          last_care_event_on: Date.add(today, -interval)
        }

      1 ->
        %{
          next_due_on: Date.add(today, -1),
          last_watered_on: Date.add(today, -(interval + 1)),
          last_care_event_on: Date.add(today, -(interval + 1))
        }

      2 ->
        %{
          next_due_on: Date.add(today, 1),
          last_checked_on: Date.add(today, -1),
          last_care_event_on: Date.add(today, -1)
        }

      3 ->
        %{
          next_due_on: Date.add(today, interval),
          manual_due_on: Date.add(today, 1),
          last_checked_on: Date.add(today, -1),
          last_care_event_on: Date.add(today, -1)
        }

      4 ->
        %{
          next_due_on: Date.add(today, 2),
          last_watered_on: Date.add(today, -1),
          last_care_event_on: Date.add(today, -1)
        }
    end
  end
end
