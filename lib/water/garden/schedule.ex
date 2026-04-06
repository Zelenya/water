defmodule Water.Garden.Schedule do
  @moduledoc """
  Scheduling means two related things:
   - Determines the state/status of care items based on their schedule and due date.
    - Provides the transition rules for care items (via transition/command builders)
  """

  alias Water.Garden.CareItem
  alias Water.Garden.Schedule.Transition

  @type status() :: :normal | :soon | :due_today | :overdue | :manually_flagged | :no_schedule
  @type postpone_days() :: :usual_interval | {:days, pos_integer()}

  @spec effective_due_on(CareItem.t()) :: Date.t() | nil
  @doc """
  Returns the effective due date for a care item.
  If the care item has a manual due date, returns it. Otherwise, returns the next due date.
  Note that `nil` means that item has no schedule and it's a normal state.
  """
  def effective_due_on(%CareItem{manual_due_on: %Date{} = manual_due_on}), do: manual_due_on
  def effective_due_on(%CareItem{next_due_on: %Date{} = next_due_on}), do: next_due_on
  def effective_due_on(%CareItem{}), do: nil

  @spec no_schedule?(CareItem.t()) :: boolean()
  def no_schedule?(%CareItem{} = care_item), do: is_nil(effective_due_on(care_item))

  @spec status(CareItem.t(), Date.t()) :: status()
  def status(%CareItem{} = care_item, %Date{} = today) do
    case effective_due_on(care_item) do
      nil ->
        :no_schedule

      %Date{} = due_on ->
        cond do
          Date.compare(due_on, today) == :lt ->
            :overdue

          Date.compare(due_on, today) == :eq ->
            :due_today

          # For now, it's just "tomorrow". I like that it's shorter and might revisit later
          Date.compare(due_on, Date.add(today, 1)) == :eq ->
            :soon

          # Manually flagged is a derived state for items with a manual due date
          match?(%Date{}, care_item.manual_due_on) ->
            :manually_flagged

          true ->
            :normal
        end
    end
  end

  @spec water(CareItem.t(), Date.t()) :: Transition.t()
  def water(%CareItem{} = care_item, %Date{} = occurred_on) do
    interval = care_item.watering_interval_days
    resulting_due_on = due_from_interval(interval, occurred_on)

    %Transition{
      event_type: :watered,
      occurred_on: occurred_on,
      previous_due_on: effective_due_on(care_item),
      resulting_due_on: resulting_due_on,
      watering_interval_days: interval,
      next_due_on: resulting_due_on,
      manual_due_on: nil,
      postpone_days: nil,
      manual_target_on: nil,
      last_watered_on: occurred_on,
      last_checked_on: nil,
      last_care_event_on: occurred_on
    }
  end

  @spec soil_check(CareItem.t(), postpone_days(), Date.t()) ::
          {:ok, Transition.t()} | {:error, :invalid_postpone_days}
  def soil_check(
        %CareItem{watering_interval_days: interval} = care_item,
        :usual_interval,
        %Date{} = occurred_on
      )
      when is_integer(interval) and interval > 0 do
    build_soil_check_transition(care_item, interval, occurred_on)
  end

  def soil_check(%CareItem{} = care_item, {:days, days}, %Date{} = occurred_on)
      when is_integer(days) and days > 0 do
    build_soil_check_transition(care_item, days, occurred_on)
  end

  def soil_check(%CareItem{}, _postpone_days, %Date{}), do: {:error, :invalid_postpone_days}

  @spec mark_needs_watering(CareItem.t(), Date.t(), Date.t()) ::
          {:ok, Transition.t()} | {:error, :invalid_manual_target}
  def mark_needs_watering(%CareItem{} = care_item, %Date{} = target_on, %Date{} = occurred_on) do
    case Date.compare(target_on, occurred_on) do
      :lt ->
        {:error, :invalid_manual_target}

      :eq ->
        {:ok, build_flag_transition(care_item, target_on, occurred_on)}

      :gt ->
        {:ok, build_flag_transition(care_item, target_on, occurred_on)}
    end
  end

  @spec clear_schedule(CareItem.t(), Date.t()) :: Transition.t()
  def clear_schedule(%CareItem{} = care_item, %Date{} = occurred_on) do
    %Transition{
      event_type: :schedule_changed,
      occurred_on: occurred_on,
      previous_due_on: effective_due_on(care_item),
      resulting_due_on: nil,
      watering_interval_days: nil,
      next_due_on: nil,
      manual_due_on: nil,
      postpone_days: nil,
      manual_target_on: nil,
      last_watered_on: care_item.last_watered_on,
      last_checked_on: care_item.last_checked_on,
      last_care_event_on: occurred_on
    }
  end

  @spec build_soil_check_transition(CareItem.t(), pos_integer(), Date.t()) ::
          {:ok, Transition.t()}
  defp build_soil_check_transition(%CareItem{} = care_item, postpone_days, %Date{} = occurred_on) do
    previous_due_on = effective_due_on(care_item)
    resulting_due_on = Date.add(soil_check_anchor_on(care_item, occurred_on), postpone_days)
    manual_due_on = manual_due_on_for_soil_check(care_item, resulting_due_on)

    {:ok,
     %Transition{
       event_type: :soil_checked,
       occurred_on: occurred_on,
       previous_due_on: previous_due_on,
       resulting_due_on: resulting_due_on,
       watering_interval_days: care_item.watering_interval_days,
       next_due_on: next_due_on_for_soil_check(care_item, resulting_due_on),
       manual_due_on: manual_due_on,
       postpone_days: postpone_days,
       manual_target_on: nil,
       last_watered_on: nil,
       last_checked_on: occurred_on,
       last_care_event_on: occurred_on
     }}
  end

  @spec soil_check_anchor_on(CareItem.t(), Date.t()) :: Date.t()
  defp soil_check_anchor_on(%CareItem{} = care_item, %Date{} = occurred_on) do
    effective_due_on(care_item) || occurred_on
  end

  @spec build_flag_transition(CareItem.t(), Date.t(), Date.t()) :: Transition.t()
  defp build_flag_transition(%CareItem{} = care_item, %Date{} = target_on, %Date{} = occurred_on) do
    %Transition{
      event_type: :manual_needs_watering,
      occurred_on: occurred_on,
      previous_due_on: effective_due_on(care_item),
      resulting_due_on: target_on,
      watering_interval_days: care_item.watering_interval_days,
      next_due_on: care_item.next_due_on,
      manual_due_on: target_on,
      postpone_days: nil,
      manual_target_on: target_on,
      last_watered_on: nil,
      last_checked_on: nil,
      last_care_event_on: occurred_on
    }
  end

  @spec due_from_interval(pos_integer() | nil, Date.t()) :: Date.t() | nil
  defp due_from_interval(interval, %Date{} = occurred_on)
       when is_integer(interval) and interval > 0 do
    Date.add(occurred_on, interval)
  end

  defp due_from_interval(nil, %Date{}), do: nil

  @spec manual_due_on_for_soil_check(CareItem.t(), Date.t()) :: Date.t() | nil
  defp manual_due_on_for_soil_check(
         %CareItem{watering_interval_days: interval},
         _resulting_due_on
       )
       when is_integer(interval) and interval > 0,
       do: nil

  defp manual_due_on_for_soil_check(%CareItem{}, %Date{} = resulting_due_on), do: resulting_due_on

  @spec next_due_on_for_soil_check(CareItem.t(), Date.t()) :: Date.t() | nil
  defp next_due_on_for_soil_check(
         %CareItem{watering_interval_days: interval},
         %Date{} = resulting_due_on
       )
       when is_integer(interval) and interval > 0,
       do: resulting_due_on

  defp next_due_on_for_soil_check(%CareItem{}, %Date{}), do: nil
end
