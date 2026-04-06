defmodule WaterWeb.GardenDailyLoopFeatureTest do
  use WaterWeb.ConnCase, async: false

  import PhoenixTest

  alias Water.GardenFixtures

  test "member can work through a representative daily care loop", %{conn: conn} do
    %{today_item: today_item, overdue_item: overdue_item, later_item: later_item} =
      seed_board()

    conn
    |> visit("/")
    |> assert_has("#garden-shell")
    |> assert_has("#header-active-member", "Active member: A")
    |> click_button("#tool-dock-desktop-water", "Water")
    |> click_button("#section-item-tile-#{today_item.id}", today_item.name)
    |> assert_has("#section-item-tile-#{today_item.id}-feedback", "Watered")
    |> refute_has("#today-panel-item-#{today_item.id}")
    |> click_button("#tool-dock-desktop-soil-check", "Soil Check")
    |> click_button("#section-item-tile-#{overdue_item.id}", overdue_item.name)
    |> click_button("#care-action-modal-soil-usual", "Usual interval")
    |> assert_has("#section-item-tile-#{overdue_item.id}-feedback", "+3d")
    |> click_button("#tool-dock-desktop-needs-water", "Needs Water")
    |> click_button("#section-item-tile-#{later_item.id}", later_item.name)
    |> assert_has("#section-item-tile-#{later_item.id}-feedback", "Needs Watering Today")
    |> assert_has("#today-panel-item-#{later_item.id}")
    |> click_button("#tool-dock-desktop-browse", "Browse")
    |> click_button("#section-item-tile-#{later_item.id}", later_item.name)
    |> click_button("#item-detail-schedule-watering", "Schedule one")
    |> click_button("#care-action-modal-schedule-tomorrow", "Tomorrow")
    |> assert_has("#item-detail-feedback", "Needs Watering on")
    |> refute_has("#today-panel-item-#{later_item.id}")
    |> click_link("#filter-chip-tomorrow", "Soon")
    |> assert_has("#section-item-tile-#{later_item.id}")
    |> assert_has("#header-active-member", "Active member: A")
  end

  defp seed_board do
    household = GardenFixtures.default_household_fixture()
    _member = GardenFixtures.member_fixture(household, %{name: "A"})
    today = household_today(household)

    front = GardenFixtures.section_fixture(household, %{name: "Front", position: 0})
    back = GardenFixtures.section_fixture(household, %{name: "Back", position: 1})

    today_item =
      GardenFixtures.care_item_fixture(front, %{name: "Today", next_due_on: today, position: 0})

    overdue_item =
      GardenFixtures.care_item_fixture(front, %{
        name: "Overdue",
        next_due_on: Date.add(today, -1),
        position: 1
      })

    later_item =
      GardenFixtures.care_item_fixture(back, %{
        name: "Later",
        next_due_on: Date.add(today, 4),
        position: 0
      })

    %{
      today_item: today_item,
      overdue_item: overdue_item,
      later_item: later_item
    }
  end

  defp household_today(household) do
    timezone = household.timezone || "Etc/UTC"
    now = DateTime.now!(timezone)
    DateTime.to_date(now)
  end
end
