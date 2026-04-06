defmodule Water.Garden.SectionTest do
  use Water.DataCase, async: true

  alias Water.Garden.Section
  alias Water.GardenFixtures

  describe "create_changeset/3" do
    test "enforces section names per household" do
      household = GardenFixtures.household_fixture()
      _section = GardenFixtures.section_fixture(household, %{name: "Front of the House"})

      {:error, changeset} =
        %Section{}
        |> Section.create_changeset(household, %{name: "Front of the House", position: 1})
        |> Repo.insert()

      assert "has already been taken" in errors_on(changeset).name
    end
  end
end
