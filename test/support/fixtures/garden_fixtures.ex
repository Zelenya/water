defmodule Water.GardenFixtures do
  alias Water.Garden.{CareItem, CareEvent, Section}
  alias Water.Households
  alias Water.Households.{Household, Member}
  alias Water.Repo

  @spec household_fixture(map()) :: Household.t()
  def household_fixture(attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        name: "Household #{unique_integer()}",
        slug: "household-#{unique_integer()}",
        timezone: "America/Los_Angeles"
      })

    %Household{}
    |> Household.changeset(attrs)
    |> Repo.insert!()
  end

  @spec default_household_fixture() :: Household.t()
  def default_household_fixture do
    {:ok, household} = Households.bootstrap_default_household()
    household
  end

  @spec member_fixture(map()) :: Member.t()
  def member_fixture(attrs \\ %{})

  def member_fixture(%Household{} = household) do
    member_fixture(household, %{})
  end

  def member_fixture(attrs) when is_map(attrs) do
    household = household_fixture()
    member_fixture(household, attrs)
  end

  @spec member_fixture(Household.t(), map()) :: Member.t()
  def member_fixture(%Household{} = household, attrs) do
    attrs =
      Enum.into(attrs, %{
        name: "Member #{unique_integer()}",
        color: "#22C55E",
        active: true
      })

    %Member{}
    |> Member.create_changeset(household, attrs)
    |> Repo.insert!()
  end

  @spec section_fixture(map()) :: Section.t()
  def section_fixture(attrs \\ %{})

  def section_fixture(%Household{} = household) do
    section_fixture(household, %{})
  end

  def section_fixture(attrs) when is_map(attrs) do
    household = household_fixture()
    section_fixture(household, attrs)
  end

  @spec section_fixture(Household.t(), map()) :: Section.t()
  def section_fixture(%Household{} = household, attrs) do
    attrs =
      Enum.into(attrs, %{
        name: "Section #{unique_integer()}",
        position: 0
      })

    %Section{}
    |> Section.create_changeset(household, attrs)
    |> Repo.insert!()
  end

  @spec care_item_fixture(map()) :: CareItem.t()
  def care_item_fixture(attrs \\ %{})

  def care_item_fixture(%Section{} = section) do
    care_item_fixture(section, %{})
  end

  def care_item_fixture(attrs) when is_map(attrs) do
    section = section_fixture()
    care_item_fixture(section, attrs)
  end

  @spec care_item_fixture(Section.t(), map()) :: CareItem.t()
  def care_item_fixture(%Section{household_id: household_id} = section, attrs) do
    household = Repo.get!(Household, household_id)

    attrs =
      Enum.into(attrs, %{
        name: "Care Item #{unique_integer()}",
        type: :plant,
        watering_interval_days: 3,
        next_due_on: Date.utc_today(),
        position: 0
      })

    %CareItem{}
    |> CareItem.create_changeset(household, section, attrs)
    |> Repo.insert!()
  end

  @spec care_event_fixture(CareItem.t(), Member.t(), map()) :: CareEvent.t()
  def care_event_fixture(%CareItem{} = care_item, %Member{} = member, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        event_type: :watered,
        occurred_on: Date.utc_today(),
        previous_due_on: Date.utc_today(),
        resulting_due_on: Date.add(Date.utc_today(), 3)
      })

    %CareEvent{}
    |> CareEvent.changeset(care_item, member, attrs)
    |> Repo.insert!()
  end

  @spec unique_integer() :: pos_integer()
  defp unique_integer do
    System.unique_integer([:positive])
  end
end
