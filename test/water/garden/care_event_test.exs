defmodule Water.Garden.CareEventTest do
  use Water.DataCase, async: true

  alias Water.Garden.CareEvent
  alias Water.GardenFixtures

  describe "changeset/4" do
    test "requires postpone_days for soil checks" do
      care_item = GardenFixtures.care_item_fixture()
      household = Repo.get!(Water.Households.Household, care_item.household_id)
      member = GardenFixtures.member_fixture(household)

      changeset =
        CareEvent.changeset(%CareEvent{}, care_item, member, %{
          event_type: :soil_checked,
          occurred_on: ~D[2026-03-27],
          previous_due_on: ~D[2026-03-27],
          resulting_due_on: ~D[2026-03-30]
        })

      assert "can't be blank" in errors_on(changeset).postpone_days
    end

    test "requires manual_target_on for manual flags" do
      care_item = GardenFixtures.care_item_fixture()
      household = Repo.get!(Water.Households.Household, care_item.household_id)
      member = GardenFixtures.member_fixture(household)

      changeset =
        CareEvent.changeset(%CareEvent{}, care_item, member, %{
          event_type: :manual_needs_watering,
          occurred_on: ~D[2026-03-27],
          previous_due_on: ~D[2026-03-27],
          resulting_due_on: ~D[2026-03-28]
        })

      assert "can't be blank" in errors_on(changeset).manual_target_on
    end

    test "does not accept manual or postpone metadata for schedule change events" do
      care_item = GardenFixtures.care_item_fixture()
      household = Repo.get!(Water.Households.Household, care_item.household_id)
      member = GardenFixtures.member_fixture(household)

      changeset =
        CareEvent.changeset(%CareEvent{}, care_item, member, %{
          event_type: :schedule_changed,
          occurred_on: ~D[2026-03-27],
          postpone_days: 2,
          manual_target_on: ~D[2026-03-28],
          previous_due_on: ~D[2026-03-27],
          resulting_due_on: ~D[2026-03-27]
        })

      assert "must be blank for this event type" in errors_on(changeset).postpone_days
      assert "must be blank for this event type" in errors_on(changeset).manual_target_on
    end

    test "allows watered events to omit the resulting due date for no-schedule items" do
      care_item = GardenFixtures.care_item_fixture()
      household = Repo.get!(Water.Households.Household, care_item.household_id)
      member = GardenFixtures.member_fixture(household)

      changeset =
        CareEvent.changeset(%CareEvent{}, care_item, member, %{
          event_type: :watered,
          occurred_on: ~D[2026-03-27],
          previous_due_on: ~D[2026-03-28],
          resulting_due_on: nil
        })

      assert changeset.valid?
    end

    test "allows manual reminders to omit a previous due date for no-schedule items" do
      care_item = GardenFixtures.care_item_fixture()
      household = Repo.get!(Water.Households.Household, care_item.household_id)
      member = GardenFixtures.member_fixture(household)

      changeset =
        CareEvent.changeset(%CareEvent{}, care_item, member, %{
          event_type: :manual_needs_watering,
          occurred_on: ~D[2026-03-27],
          previous_due_on: nil,
          resulting_due_on: ~D[2026-03-28],
          manual_target_on: ~D[2026-03-28]
        })

      assert changeset.valid?
    end

    test "allows soil checks to omit a previous due date for no-schedule items" do
      care_item = GardenFixtures.care_item_fixture()
      household = Repo.get!(Water.Households.Household, care_item.household_id)
      member = GardenFixtures.member_fixture(household)

      changeset =
        CareEvent.changeset(%CareEvent{}, care_item, member, %{
          event_type: :soil_checked,
          occurred_on: ~D[2026-03-27],
          postpone_days: 2,
          previous_due_on: nil,
          resulting_due_on: ~D[2026-03-29]
        })

      assert changeset.valid?
    end
  end
end
