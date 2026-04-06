defmodule Water.Garden.SchedulePropertiesTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import StreamData

  alias Water.Garden.{CareItem, Schedule}

  property "watering resets from the action date and clears any manual due date" do
    check all(
            interval <- integer(1..30),
            occurred_on <- date_generator(),
            next_due_on <- date_generator(),
            manual_due_on <- optional_date_generator()
          ) do
      care_item =
        build_item(%{
          watering_interval_days: interval,
          next_due_on: next_due_on,
          manual_due_on: manual_due_on
        })

      transition = Schedule.water(care_item, occurred_on)

      assert transition.previous_due_on == Schedule.effective_due_on(care_item)
      assert transition.resulting_due_on == Date.add(occurred_on, interval)
      assert transition.manual_due_on == nil
      assert transition.last_watered_on == occurred_on
    end
  end

  property "watering no-schedule items leaves them without a due date" do
    check all(
            occurred_on <- date_generator(),
            manual_due_on <- optional_date_generator()
          ) do
      care_item =
        build_item(%{
          watering_interval_days: nil,
          next_due_on: nil,
          manual_due_on: manual_due_on
        })

      transition = Schedule.water(care_item, occurred_on)

      assert transition.resulting_due_on == nil
      assert transition.watering_interval_days == nil
      assert transition.manual_due_on == nil
    end
  end

  property "soil check postpones from the effective due date when one exists" do
    check all(
            interval <- integer(1..30),
            postpone_days <- integer(1..30),
            occurred_on <- date_generator(),
            next_due_on <- date_generator(),
            manual_due_on <- optional_date_generator()
          ) do
      care_item =
        build_item(%{
          watering_interval_days: interval,
          next_due_on: next_due_on,
          manual_due_on: manual_due_on
        })

      assert {:ok, transition} =
               Schedule.soil_check(care_item, {:days, postpone_days}, occurred_on)

      assert transition.previous_due_on == Schedule.effective_due_on(care_item)

      assert transition.resulting_due_on ==
               Date.add(Schedule.effective_due_on(care_item), postpone_days)

      assert transition.manual_due_on == nil
      assert transition.last_checked_on == occurred_on
    end
  end

  property "soil check anchors from today when no active due date exists" do
    check all(
            postpone_days <- integer(1..30),
            occurred_on <- date_generator()
          ) do
      care_item = build_item(%{watering_interval_days: nil, next_due_on: nil, manual_due_on: nil})

      assert {:ok, transition} =
               Schedule.soil_check(care_item, {:days, postpone_days}, occurred_on)

      assert transition.previous_due_on == nil
      assert transition.resulting_due_on == Date.add(occurred_on, postpone_days)
      assert transition.manual_due_on == transition.resulting_due_on
    end
  end

  property "usual-interval soil check matches custom days for the same interval" do
    check all(
            interval <- integer(1..30),
            occurred_on <- date_generator(),
            next_due_on <- date_generator(),
            manual_due_on <- optional_date_generator()
          ) do
      care_item =
        build_item(%{
          watering_interval_days: interval,
          next_due_on: next_due_on,
          manual_due_on: manual_due_on
        })

      assert {:ok, usual_transition} =
               Schedule.soil_check(care_item, :usual_interval, occurred_on)

      assert {:ok, custom_transition} =
               Schedule.soil_check(care_item, {:days, interval}, occurred_on)

      assert usual_transition == custom_transition
    end
  end

  property "manual needs-water rejects past targets" do
    check all(
            occurred_on <- date_generator(),
            days_back <- integer(1..30),
            next_due_on <- date_generator(),
            manual_due_on <- optional_date_generator()
          ) do
      target_on = Date.add(occurred_on, -days_back)
      care_item = build_item(%{next_due_on: next_due_on, manual_due_on: manual_due_on})

      assert Schedule.mark_needs_watering(care_item, target_on, occurred_on) ==
               {:error, :invalid_manual_target}
    end
  end

  property "manual needs-water preserves the underlying schedule semantics" do
    check all(
            interval <- integer(1..30),
            occurred_on <- date_generator(),
            target_offset <- integer(0..30),
            next_due_on <- date_generator()
          ) do
      target_on = Date.add(occurred_on, target_offset)

      care_item =
        build_item(%{
          watering_interval_days: interval,
          next_due_on: next_due_on
        })

      assert {:ok, transition} =
               Schedule.mark_needs_watering(care_item, target_on, occurred_on)

      assert transition.previous_due_on == next_due_on
      assert transition.resulting_due_on == target_on
      assert transition.manual_due_on == target_on
      assert transition.manual_target_on == target_on
      assert transition.last_watered_on == nil
      assert transition.last_checked_on == nil

      watered_item = %{care_item | manual_due_on: transition.manual_due_on}
      watered_transition = Schedule.water(watered_item, occurred_on)

      assert watered_transition.resulting_due_on == Date.add(occurred_on, interval)
      assert watered_transition.manual_due_on == nil
    end
  end

  defp build_item(attrs) do
    struct(CareItem, Map.merge(%{watering_interval_days: 3, next_due_on: ~D[2026-03-27]}, attrs))
  end

  defp date_generator do
    gen all(day_offset <- integer(-120..120)) do
      Date.add(~D[2026-03-27], day_offset)
    end
  end

  defp optional_date_generator do
    one_of([constant(nil), date_generator()])
  end
end
