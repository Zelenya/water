defmodule Water.Garden.Sections do
  import Ecto.Query, warn: false

  alias Ecto.Multi
  alias Water.Garden.{Attrs, CareEvent, CareItem, Section}
  alias Water.Households.Household
  alias Water.Repo

  @type result(value) :: {:ok, value} | {:error, Ecto.Changeset.t()}

  @spec list_sections(Household.t()) :: [Section.t()]
  def list_sections(%Household{id: household_id}) do
    from(section in Section,
      where: section.household_id == ^household_id,
      order_by: [asc: section.position, asc: section.inserted_at]
    )
    |> Repo.all()
  end

  @spec get_section!(Household.t(), Section.id()) :: Section.t()
  def get_section!(%Household{id: household_id}, id) when is_integer(id) do
    from(section in Section,
      where: section.household_id == ^household_id and section.id == ^id
    )
    |> Repo.one!()
  end

  @spec create_section(Household.t(), map()) :: result(Section.t())
  def create_section(%Household{id: household_id} = household, attrs) when is_map(attrs) do
    attrs =
      maybe_put_default_attr(attrs, :position, next_section_position(household_id))

    %Section{}
    |> Section.create_changeset(household, attrs)
    |> Repo.insert()
  end

  @spec change_section(Section.t(), map()) :: Ecto.Changeset.t()
  def change_section(%Section{} = section, attrs \\ %{}) when is_map(attrs) do
    Section.update_changeset(section, attrs)
  end

  @spec update_section(Section.t(), map()) :: result(Section.t())
  def update_section(%Section{} = section, attrs) when is_map(attrs) do
    section
    |> Section.update_changeset(attrs)
    |> Repo.update()
  end

  @spec delete_section(Section.t()) :: result(Section.t())
  def delete_section(%Section{id: section_id, household_id: household_id} = section) do
    care_item_ids_query =
      from(care_item in CareItem,
        where: care_item.household_id == ^household_id and care_item.section_id == ^section_id,
        select: care_item.id
      )

    care_events_query =
      from(care_event in CareEvent,
        where:
          care_event.household_id == ^household_id and
            care_event.care_item_id in subquery(care_item_ids_query)
      )

    care_items_query =
      from(care_item in CareItem,
        where: care_item.household_id == ^household_id and care_item.section_id == ^section_id
      )

    multi =
      Multi.new()
      |> Multi.delete_all(:care_events, care_events_query)
      |> Multi.delete_all(:care_items, care_items_query)
      |> Multi.delete(:section, section)

    case Repo.transaction(multi) do
      {:ok, %{section: deleted_section}} ->
        {:ok, deleted_section}

      {:error, :section, %Ecto.Changeset{} = changeset, _changes_so_far} ->
        {:error, changeset}
    end
  end

  @spec next_section_position(Household.id()) :: non_neg_integer()
  defp next_section_position(household_id) do
    from(section in Section,
      where: section.household_id == ^household_id,
      select: max(section.position)
    )
    |> Repo.one()
    |> case do
      nil -> 0
      position -> position + 1
    end
  end

  @spec maybe_put_default_attr(map(), atom(), term()) :: map()
  defp maybe_put_default_attr(attrs, key, value) do
    case Attrs.has_attr?(attrs, key) do
      true -> attrs
      false -> Attrs.put_attr(attrs, key, value)
    end
  end
end
