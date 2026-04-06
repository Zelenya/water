defmodule Water.Garden.ScheduleTest do
  use ExUnit.Case, async: true

  alias Water.Garden.{CareItem, Schedule}

  describe "effective_due_on/1 and status/2" do
    test "prefers manual_due_on for effective due date" do
      care_item =
        build_item(%{
          next_due_on: ~D[2026-03-29],
          manual_due_on: ~D[2026-03-28]
        })

      assert Schedule.effective_due_on(care_item) == ~D[2026-03-28]
    end

    test "uses no_schedule when no active due date exists" do
      assert Schedule.status(
               build_item(%{watering_interval_days: nil, next_due_on: nil}),
               ~D[2026-03-27]
             ) ==
               :no_schedule
    end

    test "prioritizes overdue, today, tomorrow, manual, and normal" do
      today = ~D[2026-03-27]

      assert Schedule.status(build_item(%{next_due_on: ~D[2026-03-26]}), today) == :overdue
      assert Schedule.status(build_item(%{next_due_on: today}), today) == :due_today

      assert Schedule.status(
               build_item(%{next_due_on: ~D[2026-04-01], manual_due_on: ~D[2026-03-28]}),
               today
             ) == :soon

      assert Schedule.status(
               build_item(%{next_due_on: ~D[2026-04-01], manual_due_on: ~D[2026-03-29]}),
               today
             ) == :manually_flagged

      assert Schedule.status(build_item(%{next_due_on: ~D[2026-03-28]}), today) == :soon
      assert Schedule.status(build_item(%{next_due_on: ~D[2026-03-30]}), today) == :normal
    end
  end

  describe "water/2" do
    test "resets recurring items from the action date and clears manual due" do
      care_item =
        build_item(%{
          watering_interval_days: 3,
          next_due_on: ~D[2026-03-29],
          manual_due_on: ~D[2026-03-28]
        })

      transition = Schedule.water(care_item, ~D[2026-03-27])

      assert transition.previous_due_on == ~D[2026-03-28]
      assert transition.resulting_due_on == ~D[2026-03-30]
      assert transition.watering_interval_days == 3
      assert transition.manual_due_on == nil
      assert transition.last_watered_on == ~D[2026-03-27]
    end

    test "returns no next due date for no-schedule items" do
      care_item =
        build_item(%{
          watering_interval_days: nil,
          next_due_on: nil,
          manual_due_on: ~D[2026-03-28]
        })

      transition = Schedule.water(care_item, ~D[2026-03-27])

      assert transition.previous_due_on == ~D[2026-03-28]
      assert transition.resulting_due_on == nil
      assert transition.watering_interval_days == nil
      assert transition.manual_due_on == nil
    end
  end

  describe "soil_check/3" do
    test "postpones from the effective due date and clears manual due" do
      care_item =
        build_item(%{
          watering_interval_days: 3,
          next_due_on: ~D[2026-03-29],
          manual_due_on: ~D[2026-03-28]
        })

      assert {:ok, transition} = Schedule.soil_check(care_item, {:days, 2}, ~D[2026-03-27])
      assert transition.previous_due_on == ~D[2026-03-28]
      assert transition.resulting_due_on == ~D[2026-03-30]
      assert transition.manual_due_on == nil
      assert transition.last_checked_on == ~D[2026-03-27]
    end

    test "uses the usual interval when requested" do
      care_item = build_item(%{watering_interval_days: 4, next_due_on: ~D[2026-03-27]})

      assert {:ok, transition} = Schedule.soil_check(care_item, :usual_interval, ~D[2026-03-27])
      assert transition.postpone_days == 4
      assert transition.resulting_due_on == ~D[2026-03-31]
    end

    test "anchors custom postponement from today when there is no active due date" do
      care_item = build_item(%{watering_interval_days: nil, next_due_on: nil})

      assert {:ok, transition} = Schedule.soil_check(care_item, {:days, 2}, ~D[2026-03-27])
      assert transition.previous_due_on == nil
      assert transition.resulting_due_on == ~D[2026-03-29]
      assert transition.manual_due_on == ~D[2026-03-29]
    end

    test "rejects usual interval when there is no recurring interval" do
      care_item = build_item(%{watering_interval_days: nil, next_due_on: nil})

      assert Schedule.soil_check(care_item, :usual_interval, ~D[2026-03-27]) ==
               {:error, :invalid_postpone_days}
    end

    test "rejects invalid custom postponement values" do
      care_item = build_item(%{watering_interval_days: 4, next_due_on: ~D[2026-03-27]})

      assert Schedule.soil_check(care_item, {:days, 0}, ~D[2026-03-27]) ==
               {:error, :invalid_postpone_days}
    end
  end

  describe "mark_needs_watering/3" do
    test "sets manual_due_on without changing the interval" do
      care_item =
        build_item(%{
          watering_interval_days: 7,
          next_due_on: ~D[2026-03-30]
        })

      assert {:ok, transition} =
               Schedule.mark_needs_watering(care_item, ~D[2026-03-28], ~D[2026-03-27])

      assert transition.previous_due_on == ~D[2026-03-30]
      assert transition.resulting_due_on == ~D[2026-03-28]
      assert transition.watering_interval_days == 7
      assert transition.manual_due_on == ~D[2026-03-28]
      assert transition.manual_target_on == ~D[2026-03-28]
    end

    test "rejects manual targets in the past" do
      care_item = build_item(%{next_due_on: ~D[2026-03-30]})

      assert Schedule.mark_needs_watering(care_item, ~D[2026-03-26], ~D[2026-03-27]) ==
               {:error, :invalid_manual_target}
    end
  end

  describe "clear_schedule/2" do
    test "removes interval and all due dates while preserving prior care dates" do
      care_item =
        build_item(%{
          next_due_on: ~D[2026-03-30],
          manual_due_on: ~D[2026-03-28],
          last_watered_on: ~D[2026-03-20],
          last_checked_on: ~D[2026-03-24]
        })

      transition = Schedule.clear_schedule(care_item, ~D[2026-03-27])

      assert transition.event_type == :schedule_changed
      assert transition.previous_due_on == ~D[2026-03-28]
      assert transition.resulting_due_on == nil
      assert transition.watering_interval_days == nil
      assert transition.manual_due_on == nil
      assert transition.last_watered_on == ~D[2026-03-20]
      assert transition.last_checked_on == ~D[2026-03-24]
    end
  end

  @spec build_item(map()) :: CareItem.t()
  defp build_item(attrs) do
    struct(CareItem, Map.merge(%{watering_interval_days: 3, next_due_on: ~D[2026-03-27]}, attrs))
  end
end
