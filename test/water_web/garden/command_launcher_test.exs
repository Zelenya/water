defmodule WaterWeb.Garden.CommandLauncherTest do
  use Water.DataCase, async: true

  alias Water.GardenFixtures
  alias WaterWeb.Garden.CommandLauncher
  alias WaterWeb.GardenLive.Navigation

  describe "open/1" do
    test "returns the default command list with active add item" do
      household = GardenFixtures.default_household_fixture()

      launcher = CommandLauncher.open(context_from(household))

      assert Enum.map(launcher.results, & &1.title) == ["Water", "Rain", "Soil Check", "Add Item"]
    end

    test "shows add item as disabled when there are no sections" do
      household = GardenFixtures.default_household_fixture()
      launcher = CommandLauncher.open(context_from(household))

      add_item = Enum.find(launcher.results, &(&1.id == "command-new-item"))

      refute add_item.selectable?
      assert add_item.subtitle == "Add a section first to create items"
    end

    test "returns add item as enabled when there are sections" do
      household = GardenFixtures.default_household_fixture()
      _section = GardenFixtures.section_fixture(household, %{name: "Front", position: 0})
      launcher = CommandLauncher.open(context_from(household))

      add_item = Enum.find(launcher.results, &(&1.id == "command-new-item"))

      assert add_item.selectable?
    end
  end

  describe "update_query/3" do
    test "matches tomorrow against the visible soon label" do
      household = GardenFixtures.default_household_fixture()
      section = GardenFixtures.section_fixture(household, %{name: "Front", position: 0})
      _item = GardenFixtures.care_item_fixture(section, %{name: "Mint", position: 0})
      context = household |> context_from()

      results =
        CommandLauncher.open(context)
        |> CommandLauncher.update_query("tomorrow", context)
        |> CommandLauncher.command_results()

      assert Enum.any?(results, &(&1.title == "Soon"))
    end

    test "matches items by section name" do
      household = GardenFixtures.default_household_fixture()
      section = GardenFixtures.section_fixture(household, %{name: "Front", position: 0})
      item = GardenFixtures.care_item_fixture(section, %{name: "Mint", position: 0})
      context = household |> context_from()

      results =
        CommandLauncher.open(context)
        |> CommandLauncher.update_query("front", context)
        |> CommandLauncher.item_results()

      assert Enum.any?(results, &(&1.action == {:show_item, item.id}))
    end

    test "ranks matching items by urgency " do
      household = GardenFixtures.default_household_fixture()
      section = GardenFixtures.section_fixture(household, %{name: "Front", position: 0})
      today = Navigation.household_today(household)
      context = household |> context_from()

      _first =
        GardenFixtures.care_item_fixture(section, %{
          name: "A Plant",
          next_due_on: today,
          position: 0
        })

      overdue =
        GardenFixtures.care_item_fixture(section, %{
          name: "B Overdue Plant",
          next_due_on: Date.add(today, -1),
          position: 1
        })

      _last =
        GardenFixtures.care_item_fixture(section, %{
          name: "C Plant",
          next_due_on: Date.add(today, 5),
          position: 2
        })

      [first_item | _] =
        CommandLauncher.open(context)
        |> CommandLauncher.update_query("plant", context)
        |> CommandLauncher.item_results()

      assert first_item.action == {:show_item, overdue.id}
      assert first_item.status == :overdue
    end
  end

  @spec context_from(Water.Households.Household.t()) :: CommandLauncher.context()
  defp context_from(household) do
    sections = Water.Garden.list_sections(household)
    section_lookup = Map.new(sections, &{&1.id, &1})

    %{
      household: household,
      sections: sections,
      section_lookup: section_lookup,
      today: Navigation.household_today(household),
      tool_mode: :browse,
      current_filter: :all
    }
  end
end
