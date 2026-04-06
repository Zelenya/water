defmodule Water.Garden.Schedule.Transition do
  @enforce_keys [
    :event_type,
    :occurred_on,
    :previous_due_on,
    :resulting_due_on,
    :watering_interval_days,
    :next_due_on,
    :manual_due_on,
    :last_care_event_on
  ]
  defstruct [
    :event_type,
    :occurred_on,
    :previous_due_on,
    :resulting_due_on,
    :watering_interval_days,
    :next_due_on,
    :manual_due_on,
    :postpone_days,
    :manual_target_on,
    :last_watered_on,
    :last_checked_on,
    :last_care_event_on
  ]

  @type event_type() ::
          :watered | :soil_checked | :manual_needs_watering | :schedule_changed
  @type t() :: %__MODULE__{
          event_type: event_type(),
          occurred_on: Date.t(),
          previous_due_on: Date.t() | nil,
          resulting_due_on: Date.t() | nil,
          watering_interval_days: pos_integer() | nil,
          next_due_on: Date.t() | nil,
          manual_due_on: Date.t() | nil,
          postpone_days: pos_integer() | nil,
          manual_target_on: Date.t() | nil,
          last_watered_on: Date.t() | nil,
          last_checked_on: Date.t() | nil,
          last_care_event_on: Date.t()
        }
end
