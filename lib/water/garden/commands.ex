defmodule Water.Garden.Commands do
  alias Water.Garden.{CareItem, CommandPersistence, Schedule}
  alias Water.Households.Member

  @type command_error() ::
          :invalid_manual_target
          | :invalid_postpone_days
          | :member_household_mismatch
          | :no_state_change
          | :stale
          | Ecto.Changeset.t()

  @spec water_item(CareItem.t(), Member.t(), Date.t()) ::
          {:ok, CareItem.t()} | {:error, command_error()}
  def water_item(%CareItem{} = care_item, %Member{} = member, %Date{} = occurred_on) do
    with :ok <- validate_member_household_match(care_item, member) do
      transition = Schedule.water(care_item, occurred_on)

      if CommandPersistence.no_state_change?(care_item, transition) do
        {:error, :no_state_change}
      else
        CommandPersistence.persist_transition(care_item, member, transition)
      end
    end
  end

  @spec soil_check_item(CareItem.t(), Member.t(), Schedule.postpone_days(), Date.t()) ::
          {:ok, CareItem.t()} | {:error, command_error()}
  def soil_check_item(
        %CareItem{} = care_item,
        %Member{} = member,
        postpone_days,
        %Date{} = occurred_on
      ) do
    with :ok <- validate_member_household_match(care_item, member),
         {:ok, transition} <- Schedule.soil_check(care_item, postpone_days, occurred_on) do
      if visible_due_changed?(care_item, transition) do
        CommandPersistence.persist_transition(care_item, member, transition)
      else
        {:error, :no_state_change}
      end
    end
  end

  @spec mark_item_needs_watering(CareItem.t(), Member.t(), Date.t(), Date.t()) ::
          {:ok, CareItem.t()} | {:error, command_error()}
  def mark_item_needs_watering(
        %CareItem{} = care_item,
        %Member{} = member,
        %Date{} = target_on,
        %Date{} = occurred_on
      ) do
    with :ok <- validate_member_household_match(care_item, member),
         {:ok, transition} <- Schedule.mark_needs_watering(care_item, target_on, occurred_on) do
      if visible_due_changed?(care_item, transition) do
        CommandPersistence.persist_transition(care_item, member, transition)
      else
        {:error, :no_state_change}
      end
    end
  end

  @spec clear_schedule_item(CareItem.t(), Member.t(), Date.t()) ::
          {:ok, CareItem.t()} | {:error, command_error()}
  def clear_schedule_item(%CareItem{} = care_item, %Member{} = member, %Date{} = occurred_on) do
    with :ok <- validate_member_household_match(care_item, member) do
      if Schedule.no_schedule?(care_item) do
        {:error, :no_state_change}
      else
        care_item
        |> Schedule.clear_schedule(occurred_on)
        |> then(&CommandPersistence.persist_transition(care_item, member, &1))
      end
    end
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

  @spec visible_due_changed?(CareItem.t(), Schedule.Transition.t()) :: boolean()
  defp visible_due_changed?(%CareItem{} = care_item, %Schedule.Transition{
         resulting_due_on: resulting_due_on
       }) do
    Schedule.effective_due_on(care_item) != resulting_due_on
  end
end
