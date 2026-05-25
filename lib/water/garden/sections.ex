defmodule Water.Garden.Sections do
  import Ecto.Query, warn: false

  alias Ecto.Multi
  alias Water.Garden.{Attrs, CareEvent, CareItem, Section}
  alias Water.Households.{Household, Member}
  alias Water.Repo

  @type result(value) :: {:ok, value} | {:error, Ecto.Changeset.t()}
  @type reposition_error() ::
          :member_household_mismatch
          | :empty_reposition
          | :invalid_reposition
          | :stale_reposition

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

  @spec reposition_section(Household.t(), Member.t(), Section.id(), [Section.id()]) ::
          {:ok, Section.t()} | {:error, reposition_error()}
  def reposition_section(
        %Household{id: household_id} = household,
        %Member{} = member,
        section_id,
        section_ids
      )
      when is_integer(section_id) and is_list(section_ids) do
    with :ok <- validate_member_household_match(household, member),
         :ok <- validate_section_ids_shape(section_ids) do
      Repo.transaction(fn ->
        with {:ok, current_sections} <- lock_reposition_sections(household_id),
             :ok <- validate_reposition_sections(current_sections, section_id, section_ids),
             :ok <- stage_reposition_sections(current_sections),
             :ok <- write_reposition_sections(section_ids),
             %Section{} = moved_section <-
               Repo.get_by(Section, id: section_id, household_id: household_id) do
          moved_section
        else
          nil -> Repo.rollback(:stale_reposition)
          {:error, reason} -> Repo.rollback(reason)
        end
      end)
    end
  end

  def reposition_section(%Household{}, %Member{}, _section_id, _section_ids) do
    {:error, :invalid_reposition}
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

  @spec validate_section_ids_shape([term()]) :: :ok | {:error, reposition_error()}
  defp validate_section_ids_shape([]), do: {:error, :empty_reposition}

  defp validate_section_ids_shape(section_ids) do
    cond do
      not Enum.all?(section_ids, &(is_integer(&1) and &1 > 0)) ->
        {:error, :invalid_reposition}

      Enum.uniq(section_ids) != section_ids ->
        {:error, :invalid_reposition}

      true ->
        :ok
    end
  end

  @spec lock_reposition_sections(Household.id()) :: {:ok, [Section.t()]}
  defp lock_reposition_sections(household_id) do
    sections =
      from(section in Section,
        where: section.household_id == ^household_id,
        order_by: [asc: section.position, asc: section.inserted_at],
        lock: "FOR UPDATE"
      )
      |> Repo.all()

    {:ok, sections}
  end

  @spec validate_reposition_sections([Section.t()], Section.id(), [Section.id()]) ::
          :ok | {:error, reposition_error()}
  defp validate_reposition_sections(current_sections, section_id, section_ids) do
    current_section_ids = Enum.map(current_sections, & &1.id)

    cond do
      Enum.count(section_ids, &(&1 == section_id)) != 1 ->
        {:error, :stale_reposition}

      Enum.sort(current_section_ids) != Enum.sort(section_ids) ->
        {:error, :stale_reposition}

      true ->
        :ok
    end
  end

  @spec stage_reposition_sections([Section.t()]) :: :ok | {:error, reposition_error()}
  defp stage_reposition_sections(current_sections) do
    current_sections
    |> Enum.reduce_while(:ok, fn %Section{id: section_id}, :ok ->
      {updated_count, _result} =
        from(section in Section, where: section.id == ^section_id)
        |> Repo.update_all(set: [position: -section_id])

      if updated_count == 1 do
        {:cont, :ok}
      else
        {:halt, {:error, :stale_reposition}}
      end
    end)
  end

  @spec write_reposition_sections([Section.id()]) :: :ok | {:error, reposition_error()}
  defp write_reposition_sections(section_ids) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    section_ids
    |> Enum.with_index()
    |> Enum.reduce_while(:ok, fn {section_id, position}, :ok ->
      {updated_count, _result} =
        from(section in Section, where: section.id == ^section_id)
        |> Repo.update_all(set: [position: position, updated_at: now])

      if updated_count == 1 do
        {:cont, :ok}
      else
        {:halt, {:error, :stale_reposition}}
      end
    end)
  end

  @spec validate_member_household_match(Household.t(), Member.t()) ::
          :ok | {:error, :member_household_mismatch}
  defp validate_member_household_match(
         %Household{id: household_id},
         %Member{household_id: household_id}
       ),
       do: :ok

  defp validate_member_household_match(%Household{}, %Member{}),
    do: {:error, :member_household_mismatch}
end
