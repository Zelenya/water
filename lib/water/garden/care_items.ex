defmodule Water.Garden.CareItems do
  @moduledoc """
  A (service) layer between raw ui parms (user intent) and a valid domain shape for care items.
  """
  import Ecto.Query, warn: false

  alias Ecto.Multi

  alias Water.Garden.{Attrs, CareEvent, CareItem, CareItemCard, CareItemDetail, Schedule, Section}
  alias Water.Garden.Schedule.Edit
  alias Water.Households.{Household, Member}
  alias Water.Repo

  @type update_result() ::
          {:ok, CareItem.t()} | {:error, :member_household_mismatch | Ecto.Changeset.t()}
  @managed_schedule_fields [:watering_interval_days, :next_due_on, :manual_due_on]

  @spec get_item!(Household.t(), integer()) :: CareItem.t()
  def get_item!(%Household{id: household_id}, id) when is_integer(id) do
    from(care_item in CareItem,
      where: care_item.household_id == ^household_id and care_item.id == ^id
    )
    |> Repo.one!()
  end

  @spec list_household_items(Household.t()) :: [CareItem.t()]
  def list_household_items(%Household{id: household_id}) do
    from(care_item in CareItem,
      where: care_item.household_id == ^household_id,
      order_by: [asc: care_item.section_id, asc: care_item.position, asc: care_item.inserted_at]
    )
    |> Repo.all()
  end

  @spec get_item_card!(Household.t(), integer(), Date.t()) :: CareItemCard.t()
  def get_item_card!(%Household{} = household, id, %Date{} = today) when is_integer(id) do
    household
    |> get_item!(id)
    |> CareItemCard.from_item(today)
  end

  @spec get_item_detail!(Household.t(), integer(), Date.t()) :: CareItemDetail.t()
  def get_item_detail!(%Household{} = household, id, %Date{} = today) when is_integer(id) do
    item = get_item!(household, id)

    %CareItemDetail{
      item_card: CareItemCard.from_item(item, today),
      recent_events: list_recent_events(household, item)
    }
  end

  @spec new_item_changeset(Household.t(), map()) :: Ecto.Changeset.t()
  def new_item_changeset(%Household{} = household, attrs \\ %{}) when is_map(attrs) do
    changeset = build_new_item_changeset(household, attrs, today_in_household(household))
    %{changeset | action: nil}
  end

  @spec create_item(Household.t(), map()) :: {:ok, CareItem.t()} | {:error, Ecto.Changeset.t()}
  def create_item(%Household{} = household, attrs) when is_map(attrs) do
    today = today_in_household(household)

    household
    |> build_new_item_changeset(attrs, today)
    |> Repo.insert()
  end

  @spec change_item(CareItem.t(), map()) :: Ecto.Changeset.t()
  def change_item(%CareItem{} = care_item, attrs \\ %{}) when is_map(attrs) do
    household = Repo.get!(Household, care_item.household_id)
    build_update_item_changeset(care_item, attrs, today_in_household(household))
  end

  @spec update_item(CareItem.t(), Member.t(), map()) :: update_result()
  @doc """
  Returns silent success when the submitted edit produces no effective changes.
  """
  def update_item(%CareItem{} = care_item, %Member{} = member, attrs) when is_map(attrs) do
    with :ok <- validate_member_household_match(care_item, member) do
      household = Repo.get!(Household, care_item.household_id)
      occurred_on = today_in_household(household)
      changeset = build_update_item_changeset(care_item, attrs, occurred_on)

      if changeset.valid? do
        if changeset.changes == %{} do
          {:ok, care_item}
        else
          persist_update(care_item, member, changeset, occurred_on)
        end
      else
        {:error, changeset}
      end
    end
  end

  @spec build_new_item_changeset(Household.t(), map(), Date.t()) :: Ecto.Changeset.t()
  # Don't trust the user input
  defp build_new_item_changeset(%Household{} = household, attrs, %Date{} = today) do
    normalized_attrs =
      attrs
      |> sanitize_schedule_boundary_attrs()
      |> Edit.normalize_attrs(nil, today)

    case fetch_section(household, normalized_attrs) do
      {:ok, section} ->
        normalized_attrs =
          normalized_attrs
          |> maybe_put_default_attr(:position, next_item_position(section.id))
          |> Attrs.put_attr(:lock_version, 1)

        %CareItem{}
        |> CareItem.create_changeset(household, section, normalized_attrs)
        |> Edit.validate_selection(attrs, nil)

      {:error, changeset} ->
        changeset
    end
  end

  @spec build_update_item_changeset(CareItem.t(), map(), Date.t()) :: Ecto.Changeset.t()
  defp build_update_item_changeset(%CareItem{} = care_item, attrs, %Date{} = today) do
    normalized_attrs =
      attrs
      |> sanitize_schedule_boundary_attrs()
      |> Edit.normalize_attrs(care_item, today)

    case section_for_update(care_item, normalized_attrs) do
      {:ok, section, resolved_attrs} ->
        changeset =
          care_item
          |> CareItem.update_changeset(resolved_attrs)
          |> maybe_put_section_id(section)
          |> Edit.validate_selection(attrs, care_item)

        maybe_suppress_no_visible_schedule_change(care_item, changeset, section, resolved_attrs)

      {:error, changeset} ->
        changeset
    end
  end

  @spec fetch_section(Household.t(), map()) :: {:ok, Section.t()} | {:error, Ecto.Changeset.t()}
  defp fetch_section(%Household{id: household_id}, attrs) do
    case Attrs.get_attr(attrs, :section_id) do
      nil ->
        {:error, CareItem.update_changeset(%CareItem{}, attrs)}

      value ->
        case Ecto.Type.cast(:integer, value) do
          {:ok, section_id} ->
            case Repo.get_by(Section, id: section_id, household_id: household_id) do
              %Section{} = section ->
                {:ok, section}

              nil ->
                changeset =
                  %CareItem{}
                  |> CareItem.update_changeset(attrs)
                  |> Ecto.Changeset.add_error(:section_id, "must belong to the household")

                {:error, changeset}
            end

          :error ->
            {:error, CareItem.update_changeset(%CareItem{}, attrs)}
        end
    end
  end

  @spec list_recent_events(Household.t(), CareItem.t()) :: [CareEvent.t()]
  defp list_recent_events(%Household{id: household_id}, %CareItem{id: item_id}) do
    from(care_event in CareEvent,
      where: care_event.household_id == ^household_id and care_event.care_item_id == ^item_id,
      order_by: [desc: care_event.occurred_on, desc: care_event.inserted_at],
      limit: 5,
      preload: [:actor_member]
    )
    |> Repo.all()
  end

  @spec section_for_update(CareItem.t(), map()) ::
          {:ok, nil | Section.t(), map()} | {:error, Ecto.Changeset.t()}
  defp section_for_update(%CareItem{} = care_item, attrs) do
    case Attrs.get_attr(attrs, :section_id) do
      nil ->
        {:ok, nil, attrs}

      value ->
        case Ecto.Type.cast(:integer, value) do
          {:ok, section_id} ->
            case Repo.get_by(Section, id: section_id, household_id: care_item.household_id) do
              %Section{} = section ->
                resolved_attrs =
                  if section_id != care_item.section_id do
                    maybe_put_default_attr(attrs, :position, next_item_position(section_id))
                  else
                    attrs
                  end

                {:ok, section, resolved_attrs}

              nil ->
                changeset =
                  care_item
                  |> CareItem.update_changeset(attrs)
                  |> Ecto.Changeset.add_error(:section_id, "must belong to the household")

                {:error, changeset}
            end

          :error ->
            {:error, CareItem.update_changeset(care_item, attrs)}
        end
    end
  end

  @spec maybe_put_section_id(Ecto.Changeset.t(), nil | Section.t()) :: Ecto.Changeset.t()
  defp maybe_put_section_id(changeset, nil), do: changeset

  defp maybe_put_section_id(changeset, %Section{id: section_id}) do
    Ecto.Changeset.put_change(changeset, :section_id, section_id)
  end

  @spec persist_update(CareItem.t(), Member.t(), Ecto.Changeset.t(), Date.t()) :: update_result()
  defp persist_update(
         %CareItem{} = care_item,
         %Member{} = member,
         changeset,
         %Date{} = occurred_on
       ) do
    multi = build_update_multi(care_item, member, changeset, occurred_on)

    case Repo.transaction(multi) do
      {:ok, %{care_item: updated_item}} ->
        {:ok, updated_item}

      {:error, :care_item, %Ecto.Changeset{} = changeset, _changes_so_far} ->
        {:error, changeset}

      {:error, :care_event, %Ecto.Changeset{} = changeset, _changes_so_far} ->
        {:error, changeset}
    end
  end

  @dialyzer {:nowarn_function, build_update_multi: 4}
  @spec build_update_multi(CareItem.t(), Member.t(), Ecto.Changeset.t(), Date.t()) :: Multi.t()
  defp build_update_multi(
         %CareItem{} = care_item,
         %Member{} = member,
         %Ecto.Changeset{} = changeset,
         %Date{} = occurred_on
       ) do
    Multi.new()
    |> Multi.update(:care_item, changeset)
    |> maybe_insert_schedule_event(care_item, member, changeset, occurred_on)
  end

  @spec maybe_insert_schedule_event(
          Multi.t(),
          CareItem.t(),
          Member.t(),
          Ecto.Changeset.t(),
          Date.t()
        ) :: Multi.t()
  defp maybe_insert_schedule_event(
         multi,
         %CareItem{} = care_item,
         %Member{} = member,
         %Ecto.Changeset{} = changeset,
         %Date{} = occurred_on
       ) do
    case schedule_event_attrs(care_item, changeset, occurred_on) do
      nil ->
        multi

      attrs ->
        care_event_changeset = CareEvent.changeset(%CareEvent{}, care_item, member, attrs)
        Multi.insert(multi, :care_event, care_event_changeset)
    end
  end

  @spec schedule_event_attrs(CareItem.t(), Ecto.Changeset.t(), Date.t()) :: nil | map()
  defp schedule_event_attrs(
         %CareItem{} = care_item,
         %Ecto.Changeset{} = changeset,
         %Date{} = occurred_on
       ) do
    updated_item = Ecto.Changeset.apply_changes(changeset)

    if schedule_fields_changed?(changeset) and
         Schedule.effective_due_on(care_item) != Schedule.effective_due_on(updated_item) do
      %{
        event_type: :schedule_changed,
        occurred_on: occurred_on,
        previous_due_on: Schedule.effective_due_on(care_item),
        resulting_due_on: Schedule.effective_due_on(updated_item)
      }
    end
  end

  @spec schedule_fields_changed?(Ecto.Changeset.t()) :: boolean()
  defp schedule_fields_changed?(%Ecto.Changeset{changes: changes}) do
    Enum.any?(@managed_schedule_fields, &Map.has_key?(changes, &1))
  end

  @spec next_item_position(Section.id()) :: non_neg_integer()
  defp next_item_position(section_id) do
    from(care_item in CareItem,
      where: care_item.section_id == ^section_id,
      select: max(care_item.position)
    )
    |> Repo.one()
    |> case do
      nil -> 0
      position -> position + 1
    end
  end

  @spec today_in_household(Household.t()) :: Date.t()
  defp today_in_household(%Household{timezone: timezone}) do
    timezone
    |> DateTime.now!()
    |> DateTime.to_date()
  end

  @spec maybe_put_default_attr(map(), atom(), term()) :: map()
  defp maybe_put_default_attr(attrs, key, value) do
    case Attrs.has_attr?(attrs, key) do
      true -> attrs
      false -> Attrs.put_attr(attrs, key, value)
    end
  end

  @schedule_boundary_fields [:next_due_on, :manual_due_on]

  @spec maybe_suppress_no_visible_schedule_change(
          CareItem.t(),
          Ecto.Changeset.t(),
          nil | Section.t(),
          map()
        ) :: Ecto.Changeset.t()
  # There is no need to update the schedule if the changeset is invalid or no-op
  defp maybe_suppress_no_visible_schedule_change(
         %CareItem{} = care_item,
         %Ecto.Changeset{} = changeset,
         section,
         resolved_attrs
       ) do
    cond do
      not changeset.valid? ->
        changeset

      not schedule_noop?(care_item, changeset) ->
        changeset

      true ->
        care_item
        |> CareItem.update_changeset(drop_schedule_attrs(resolved_attrs))
        |> maybe_put_section_id(section)
    end
  end

  @spec schedule_noop?(CareItem.t(), Ecto.Changeset.t()) :: boolean()
  # It's effectively no-op when the schedule fields have changed,
  # but the effective due date remains the same after applying the changeset
  defp schedule_noop?(%CareItem{} = care_item, %Ecto.Changeset{} = changeset) do
    schedule_fields_changed?(changeset) and
      Schedule.effective_due_on(care_item) ==
        changeset |> Ecto.Changeset.apply_changes() |> Schedule.effective_due_on()
  end

  @spec drop_schedule_attrs(map()) :: map()
  defp drop_schedule_attrs(attrs) do
    Enum.reduce(@managed_schedule_fields, attrs, &Attrs.delete_attr(&2, &1))
  end

  @spec sanitize_schedule_boundary_attrs(map()) :: map()
  defp sanitize_schedule_boundary_attrs(attrs) do
    Enum.reduce(@schedule_boundary_fields, attrs, &Attrs.delete_attr(&2, &1))
  end

  @spec validate_member_household_match(CareItem.t(), Member.t()) ::
          :ok | {:error, :member_household_mismatch}
  defp validate_member_household_match(
         %CareItem{household_id: household_id},
         %Member{household_id: household_id}
       ),
       do: :ok

  defp validate_member_household_match(%CareItem{}, %Member{}),
    do: {:error, :member_household_mismatch}
end
