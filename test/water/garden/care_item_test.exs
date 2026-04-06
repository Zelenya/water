defmodule Water.Garden.CareItemTest do
  use Water.DataCase, async: true

  alias Water.Garden.CareItem
  alias Water.GardenFixtures

  describe "create_changeset/4" do
    test "accepts recurring items with an explicit interval" do
      household = GardenFixtures.household_fixture()
      section = GardenFixtures.section_fixture(household)

      changeset =
        CareItem.create_changeset(%CareItem{}, household, section, %{
          name: "Blueberry Bed",
          type: :bed,
          watering_interval_days: 5,
          next_due_on: ~D[2026-03-27],
          position: 0
        })

      assert Ecto.Changeset.get_field(changeset, :watering_interval_days) == 5
      assert Ecto.Changeset.get_field(changeset, :household_id) == household.id
      assert Ecto.Changeset.get_field(changeset, :section_id) == section.id
    end

    test "accepts no-schedule items without an interval or due date" do
      household = GardenFixtures.household_fixture()
      section = GardenFixtures.section_fixture(household)

      changeset =
        CareItem.create_changeset(%CareItem{}, household, section, %{
          name: "Mulberry",
          type: :plant,
          position: 0
        })

      assert changeset.valid?
      assert Ecto.Changeset.get_field(changeset, :watering_interval_days) == nil
      assert Ecto.Changeset.get_field(changeset, :next_due_on) == nil
    end

    test "rejects non-positive watering intervals" do
      household = GardenFixtures.household_fixture()
      section = GardenFixtures.section_fixture(household)

      changeset =
        CareItem.create_changeset(%CareItem{}, household, section, %{
          name: "Mulberry",
          type: :plant,
          watering_interval_days: 0,
          next_due_on: ~D[2026-03-27],
          position: 0
        })

      assert "must be greater than 0" in errors_on(changeset).watering_interval_days
    end
  end
end
