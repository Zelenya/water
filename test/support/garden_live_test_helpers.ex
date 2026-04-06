defmodule WaterWeb.GardenLiveTestHelpers do
  use WaterWeb, :verified_routes

  alias Water.Garden.CareItem
  alias Water.GardenFixtures

  @spec seed_board() :: %{
          back: Water.Garden.Section.t(),
          front: Water.Garden.Section.t(),
          later_item: CareItem.t(),
          manual_today_item: CareItem.t(),
          no_schedule_item: CareItem.t(),
          other_later_item: CareItem.t(),
          overdue_item: CareItem.t(),
          today_item: CareItem.t(),
          tomorrow_item: CareItem.t()
        }
  def seed_board do
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
      GardenFixtures.care_item_fixture(front, %{
        name: "Later",
        next_due_on: Date.add(today, 4),
        position: 2
      })

    manual_today_item =
      GardenFixtures.care_item_fixture(back, %{
        name: "Manual Today",
        next_due_on: Date.add(today, 3),
        manual_due_on: today,
        position: 0
      })

    tomorrow_item =
      GardenFixtures.care_item_fixture(back, %{
        name: "Tomorrow",
        next_due_on: Date.add(today, 1),
        position: 1
      })

    other_later_item =
      GardenFixtures.care_item_fixture(back, %{
        name: "Later Tomorrow",
        next_due_on: Date.add(today, 5),
        position: 2
      })

    no_schedule_item =
      GardenFixtures.care_item_fixture(back, %{
        name: "No Schedule",
        watering_interval_days: nil,
        next_due_on: nil,
        position: 3
      })

    %{
      back: back,
      front: front,
      later_item: later_item,
      manual_today_item: manual_today_item,
      no_schedule_item: no_schedule_item,
      other_later_item: other_later_item,
      overdue_item: overdue_item,
      today_item: today_item,
      tomorrow_item: tomorrow_item
    }
  end

  @spec household_today(Water.Households.Household.t()) :: Date.t()
  def household_today(household) do
    household.timezone
    |> DateTime.now!()
    |> DateTime.to_date()
  end

  @spec item_new_path(map()) :: String.t()
  def item_new_path(params) when map_size(params) == 0, do: ~p"/items/new"
  def item_new_path(params), do: ~p"/items/new?#{params}"
end
