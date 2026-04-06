defmodule Water.GardenTest do
  use Water.DataCase, async: true

  import Ecto.Query

  alias Water.Garden
  alias Water.Garden.{BoardSectionSummary, CareEvent, CareItemDetail}
  alias Water.GardenFixtures
  alias Water.Repo

  describe "sections and items" do
    test "list_sections/1 orders by position then inserted_at" do
      household = GardenFixtures.household_fixture()
      later = GardenFixtures.section_fixture(household, %{name: "Later", position: 1})
      earlier = GardenFixtures.section_fixture(household, %{name: "Earlier", position: 0})

      assert Enum.map(Garden.list_sections(household), & &1.id) == [earlier.id, later.id]
    end

    test "create_section/2 appends at the end when position is omitted" do
      household = GardenFixtures.household_fixture()
      _section = GardenFixtures.section_fixture(household, %{position: 0})

      assert {:ok, section} = Garden.create_section(household, %{name: "Back Yard"})
      assert section.position == 1
    end

    test "create_item/2 creates a no-schedule item when no interval is provided" do
      household = GardenFixtures.household_fixture()
      section = GardenFixtures.section_fixture(household, %{position: 0})

      assert {:ok, item} =
               Garden.create_item(household, %{
                 name: "Mint",
                 type: :plant,
                 section_id: section.id
               })

      assert item.watering_interval_days == nil
      assert item.next_due_on == nil
      assert item.position == 0
      assert item.manual_due_on == nil
    end

    test "create_item/2 rejects sections outside the household" do
      household = GardenFixtures.household_fixture()
      other_household = GardenFixtures.household_fixture()
      other_section = GardenFixtures.section_fixture(other_household)

      assert {:error, changeset} =
               Garden.create_item(household, %{
                 name: "Rosemary",
                 type: :plant,
                 section_id: other_section.id
               })

      assert "must belong to the household" in errors_on(changeset).section_id
    end

    test "update_item/3 appends at the end when moving sections without an explicit position" do
      household = GardenFixtures.household_fixture()
      member = GardenFixtures.member_fixture(household)
      source = GardenFixtures.section_fixture(household, %{name: "Source", position: 0})
      destination = GardenFixtures.section_fixture(household, %{name: "Destination", position: 1})
      _existing = GardenFixtures.care_item_fixture(destination, %{name: "Existing", position: 0})
      item = GardenFixtures.care_item_fixture(source, %{name: "Move Me", position: 0})

      assert {:ok, moved_item} = Garden.update_item(item, member, %{section_id: destination.id})

      assert moved_item.section_id == destination.id
      assert moved_item.position == 1
    end

    test "update_item/3 treats a schedule-only same-visible-date edit as a silent no-op" do
      household = GardenFixtures.household_fixture()
      member = GardenFixtures.member_fixture(household)
      section = GardenFixtures.section_fixture(household, %{name: "Front", position: 0})

      item =
        GardenFixtures.care_item_fixture(section, %{
          name: "Mint",
          watering_interval_days: 3,
          next_due_on: ~D[2026-04-05],
          manual_due_on: ~D[2026-04-02],
          position: 0
        })

      assert {:ok, updated_item} =
               Garden.update_item(item, member, %{
                 name: item.name,
                 type: :plant,
                 section_id: section.id,
                 schedule_mode: :recurring,
                 watering_interval_days: 5
               })

      assert updated_item.id == item.id
      assert updated_item.watering_interval_days == 3
      assert updated_item.next_due_on == ~D[2026-04-05]
      assert updated_item.manual_due_on == ~D[2026-04-02]
      assert Repo.aggregate(CareEvent, :count) == 0
    end

    test "update_item/3 saves non-schedule edits while suppressing same-visible-date schedule churn" do
      household = GardenFixtures.household_fixture()
      member = GardenFixtures.member_fixture(household)
      section = GardenFixtures.section_fixture(household, %{name: "Front", position: 0})

      item =
        GardenFixtures.care_item_fixture(section, %{
          name: "Mint",
          watering_interval_days: 3,
          next_due_on: ~D[2026-04-05],
          manual_due_on: ~D[2026-04-02],
          position: 0
        })

      assert {:ok, updated_item} =
               Garden.update_item(item, member, %{
                 name: "Chocolate Mint",
                 type: :plant,
                 section_id: section.id,
                 schedule_mode: :recurring,
                 watering_interval_days: 5
               })

      assert updated_item.name == "Chocolate Mint"
      assert updated_item.watering_interval_days == 3
      assert updated_item.next_due_on == ~D[2026-04-05]
      assert updated_item.manual_due_on == ~D[2026-04-02]
      assert Repo.aggregate(CareEvent, :count) == 0
    end

    test "get_item!/2 is household scoped" do
      household = GardenFixtures.household_fixture()
      other_household = GardenFixtures.household_fixture()
      section = GardenFixtures.section_fixture(household)
      item = GardenFixtures.care_item_fixture(section)

      assert Garden.get_item!(household, item.id).id == item.id
      assert_raise Ecto.NoResultsError, fn -> Garden.get_item!(other_household, item.id) end
    end
  end

  describe "list_board/3" do
    test "keeps section items ordered by position within a section" do
      household = GardenFixtures.household_fixture()
      section = GardenFixtures.section_fixture(household, %{name: "Front", position: 0})
      today = ~D[2026-03-27]

      _last =
        GardenFixtures.care_item_fixture(section, %{
          name: "Last",
          next_due_on: Date.add(today, 2),
          position: 2
        })

      _first =
        GardenFixtures.care_item_fixture(section, %{
          name: "First",
          next_due_on: today,
          position: 0
        })

      _middle =
        GardenFixtures.care_item_fixture(section, %{
          name: "Middle",
          next_due_on: Date.add(today, 1),
          position: 1
        })

      board = Garden.list_board(household, :all, today)

      assert Enum.map(Enum.at(board.sections, 0).items, & &1.item.name) == [
               "First",
               "Middle",
               "Last"
             ]
    end

    test "returns household-wide counts, grouped sections, and a household-wide needs care list" do
      household = GardenFixtures.household_fixture()
      front = GardenFixtures.section_fixture(household, %{name: "Front", position: 0})
      back = GardenFixtures.section_fixture(household, %{name: "Back", position: 1})
      today = ~D[2026-03-27]

      today_item =
        GardenFixtures.care_item_fixture(front, %{name: "Today", next_due_on: today, position: 0})

      overdue_item =
        GardenFixtures.care_item_fixture(front, %{
          name: "Overdue",
          next_due_on: Date.add(today, -1),
          position: 1
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

      manual_tomorrow_item =
        GardenFixtures.care_item_fixture(back, %{
          name: "Manual Tomorrow",
          next_due_on: Date.add(today, 4),
          manual_due_on: Date.add(today, 1),
          position: 2
        })

      _normal_item =
        GardenFixtures.care_item_fixture(back, %{
          name: "Normal",
          next_due_on: Date.add(today, 5),
          position: 3
        })

      board = Garden.list_board(household, :all, today)

      assert board.counts.today == 3
      assert board.counts.tomorrow == 2
      assert board.counts.overdue == 1

      assert Enum.map(board.needs_care_items, & &1.item.name) == [
               overdue_item.name,
               today_item.name,
               manual_today_item.name
             ]

      assert Enum.map(board.sections, & &1.section.name) == ["Front", "Back"]

      assert %BoardSectionSummary{today: 2, tomorrow: 0, overdue: 1} =
               Enum.at(board.sections, 0).summary

      assert %BoardSectionSummary{today: 1, tomorrow: 2, overdue: 0} =
               Enum.at(board.sections, 1).summary

      assert Enum.map(Enum.at(board.sections, 1).items, & &1.item.name) == [
               manual_today_item.name,
               tomorrow_item.name,
               manual_tomorrow_item.name,
               "Normal"
             ]
    end

    test "applies today, tomorrow, overdue, and no-schedule filters without changing household counts" do
      household = GardenFixtures.household_fixture()
      front = GardenFixtures.section_fixture(household, %{name: "Front", position: 0})
      back = GardenFixtures.section_fixture(household, %{name: "Back", position: 1})
      today = ~D[2026-03-27]

      _today_item =
        GardenFixtures.care_item_fixture(front, %{name: "Today", next_due_on: today, position: 0})

      _overdue_item =
        GardenFixtures.care_item_fixture(front, %{
          name: "Overdue",
          next_due_on: Date.add(today, -1),
          position: 1
        })

      _manual_today_item =
        GardenFixtures.care_item_fixture(back, %{
          name: "Manual Today",
          next_due_on: Date.add(today, 5),
          manual_due_on: today,
          position: 0
        })

      _tomorrow_item =
        GardenFixtures.care_item_fixture(back, %{
          name: "Tomorrow",
          next_due_on: Date.add(today, 1),
          position: 1
        })

      _no_schedule_item =
        GardenFixtures.care_item_fixture(back, %{
          name: "No Schedule",
          watering_interval_days: nil,
          next_due_on: nil,
          position: 2
        })

      today_board = Garden.list_board(household, :today, today)
      tomorrow_board = Garden.list_board(household, :tomorrow, today)
      overdue_board = Garden.list_board(household, :overdue, today)
      no_schedule_board = Garden.list_board(household, :no_schedule, today)

      assert today_board.counts.today == 3
      assert Enum.map(today_board.sections, & &1.section.name) == ["Front", "Back"]

      assert Enum.map(Enum.at(today_board.sections, 0).items, & &1.item.name) == [
               "Today",
               "Overdue"
             ]

      assert Enum.map(Enum.at(today_board.sections, 1).items, & &1.item.name) == [
               "Manual Today"
             ]

      assert tomorrow_board.counts.tomorrow == 1
      assert Enum.map(tomorrow_board.sections, & &1.section.name) == ["Back"]

      assert Enum.map(Enum.at(tomorrow_board.sections, 0).items, & &1.item.name) == [
               "Tomorrow"
             ]

      assert Enum.map(no_schedule_board.sections, & &1.section.name) == ["Back"]

      assert %BoardSectionSummary{today: 0, tomorrow: 0, overdue: 0} =
               Enum.at(no_schedule_board.sections, 0).summary

      assert Enum.map(Enum.at(no_schedule_board.sections, 0).items, & &1.item.name) == [
               "No Schedule"
             ]

      assert overdue_board.counts.overdue == 1
      assert Enum.map(overdue_board.sections, & &1.section.name) == ["Front"]
      assert Enum.map(Enum.at(overdue_board.sections, 0).items, & &1.item.name) == ["Overdue"]

      assert Enum.map(overdue_board.needs_care_items, & &1.item.name) == [
               "Overdue",
               "Today",
               "Manual Today"
             ]
    end

    test "orders needs care items by status, due date, section order, and position" do
      household = GardenFixtures.household_fixture()
      front = GardenFixtures.section_fixture(household, %{name: "Front", position: 0})
      back = GardenFixtures.section_fixture(household, %{name: "Back", position: 1})
      today = ~D[2026-03-27]

      overdue_front =
        GardenFixtures.care_item_fixture(front, %{
          name: "Overdue Front",
          next_due_on: Date.add(today, -1),
          position: 2
        })

      front_second =
        GardenFixtures.care_item_fixture(front, %{
          name: "Front Second",
          next_due_on: today,
          position: 1
        })

      back_first =
        GardenFixtures.care_item_fixture(back, %{
          name: "Back First",
          next_due_on: today,
          position: 0
        })

      front_first =
        GardenFixtures.care_item_fixture(front, %{
          name: "Front First",
          next_due_on: today,
          position: 0
        })

      board = Garden.list_board(household, :all, today)

      assert Enum.map(board.needs_care_items, & &1.item.name) == [
               overdue_front.name,
               front_first.name,
               front_second.name,
               back_first.name
             ]
    end
  end

  describe "get_item_detail!/3" do
    test "returns the item card with newest-first recent events and preloaded actors" do
      household = GardenFixtures.household_fixture()
      actor_a = GardenFixtures.member_fixture(household, %{name: "A"})
      actor_j = GardenFixtures.member_fixture(household, %{name: "J"})
      section = GardenFixtures.section_fixture(household)
      item = GardenFixtures.care_item_fixture(section, %{name: "Mint"})
      today = ~D[2026-03-27]

      _oldest =
        GardenFixtures.care_event_fixture(item, actor_a, %{
          event_type: :watered,
          occurred_on: ~D[2026-03-20],
          previous_due_on: ~D[2026-03-20],
          resulting_due_on: ~D[2026-03-23]
        })

      _older =
        GardenFixtures.care_event_fixture(item, actor_j, %{
          event_type: :soil_checked,
          occurred_on: ~D[2026-03-21],
          postpone_days: 2,
          previous_due_on: ~D[2026-03-21],
          resulting_due_on: ~D[2026-03-23]
        })

      _middle =
        GardenFixtures.care_event_fixture(item, actor_a, %{
          event_type: :manual_needs_watering,
          occurred_on: ~D[2026-03-22],
          manual_target_on: ~D[2026-03-23],
          previous_due_on: ~D[2026-03-24],
          resulting_due_on: ~D[2026-03-23]
        })

      _later =
        GardenFixtures.care_event_fixture(item, actor_j, %{
          event_type: :watered,
          occurred_on: ~D[2026-03-23],
          previous_due_on: ~D[2026-03-23],
          resulting_due_on: ~D[2026-03-26]
        })

      _latest_minus_one =
        GardenFixtures.care_event_fixture(item, actor_a, %{
          event_type: :soil_checked,
          occurred_on: ~D[2026-03-24],
          postpone_days: 3,
          previous_due_on: ~D[2026-03-24],
          resulting_due_on: ~D[2026-03-27]
        })

      latest =
        GardenFixtures.care_event_fixture(item, actor_j, %{
          event_type: :manual_needs_watering,
          occurred_on: ~D[2026-03-25],
          manual_target_on: ~D[2026-03-27],
          previous_due_on: ~D[2026-03-28],
          resulting_due_on: ~D[2026-03-27]
        })

      assert %CareItemDetail{} = item_detail = Garden.get_item_detail!(household, item.id, today)
      assert item_detail.item_card.item.id == item.id
      assert length(item_detail.recent_events) == 5
      assert hd(item_detail.recent_events).id == latest.id

      assert Enum.map(item_detail.recent_events, & &1.occurred_on) == [
               ~D[2026-03-25],
               ~D[2026-03-24],
               ~D[2026-03-23],
               ~D[2026-03-22],
               ~D[2026-03-21]
             ]

      assert Enum.all?(item_detail.recent_events, fn event ->
               match?(%Water.Households.Member{}, event.actor_member)
             end)
    end
  end

  describe "item commands" do
    test "water_item/3 updates the item and inserts an event atomically" do
      household = GardenFixtures.household_fixture()
      member = GardenFixtures.member_fixture(household)
      section = GardenFixtures.section_fixture(household)

      item =
        GardenFixtures.care_item_fixture(section, %{
          name: "Lavender",
          watering_interval_days: 3,
          next_due_on: ~D[2026-03-29],
          manual_due_on: ~D[2026-03-28]
        })

      assert {:ok, updated_item} = Garden.water_item(item, member, ~D[2026-03-27])

      assert updated_item.next_due_on == ~D[2026-03-30]
      assert updated_item.manual_due_on == nil
      assert updated_item.last_watered_on == ~D[2026-03-27]
      assert updated_item.last_care_event_on == ~D[2026-03-27]

      event = Repo.one!(from(care_event in CareEvent, where: care_event.care_item_id == ^item.id))

      assert event.event_type == :watered
      assert event.previous_due_on == ~D[2026-03-28]
      assert event.resulting_due_on == ~D[2026-03-30]
    end

    test "water_item/3 returns no-interval items to no schedule while recording watering" do
      household = GardenFixtures.household_fixture()
      member = GardenFixtures.member_fixture(household)
      section = GardenFixtures.section_fixture(household)

      item =
        GardenFixtures.care_item_fixture(section, %{
          name: "Silent Sage",
          watering_interval_days: nil,
          next_due_on: nil,
          manual_due_on: ~D[2026-03-28]
        })

      assert {:ok, updated_item} = Garden.water_item(item, member, ~D[2026-03-27])

      assert updated_item.next_due_on == nil
      assert updated_item.manual_due_on == nil
      assert updated_item.last_watered_on == ~D[2026-03-27]

      event = Repo.one!(from(care_event in CareEvent, where: care_event.care_item_id == ^item.id))

      assert event.event_type == :watered
      assert event.previous_due_on == ~D[2026-03-28]
      assert event.resulting_due_on == nil
    end

    test "water_item/3 returns no_state_change when a repeat tap would not change the item" do
      household = GardenFixtures.household_fixture()
      member = GardenFixtures.member_fixture(household)
      section = GardenFixtures.section_fixture(household)

      item =
        GardenFixtures.care_item_fixture(section, %{
          name: "Already Watered",
          watering_interval_days: 3,
          next_due_on: ~D[2026-03-28],
          last_watered_on: ~D[2026-03-25],
          last_care_event_on: ~D[2026-03-25]
        })

      assert {:ok, updated_item} = Garden.water_item(item, member, ~D[2026-03-28])
      assert Garden.water_item(updated_item, member, ~D[2026-03-28]) == {:error, :no_state_change}

      assert Repo.aggregate(
               from(care_event in CareEvent, where: care_event.care_item_id == ^item.id),
               :count,
               :id
             ) == 1
    end

    test "soil_check_item/4 postpones from the effective due date and clears manual due" do
      household = GardenFixtures.household_fixture()
      member = GardenFixtures.member_fixture(household)
      section = GardenFixtures.section_fixture(household)

      item =
        GardenFixtures.care_item_fixture(section, %{
          name: "Blueberry Bed",
          watering_interval_days: 3,
          next_due_on: ~D[2026-03-30],
          manual_due_on: ~D[2026-03-28]
        })

      assert {:ok, updated_item} =
               Garden.soil_check_item(item, member, :usual_interval, ~D[2026-03-27])

      assert updated_item.next_due_on == ~D[2026-03-31]
      assert updated_item.manual_due_on == nil
      assert updated_item.last_checked_on == ~D[2026-03-27]
      assert updated_item.last_care_event_on == ~D[2026-03-27]

      event = Repo.one!(from(care_event in CareEvent, where: care_event.care_item_id == ^item.id))

      assert event.event_type == :soil_checked
      assert event.postpone_days == 3
      assert event.previous_due_on == ~D[2026-03-28]
      assert event.resulting_due_on == ~D[2026-03-31]
    end

    test "soil_check_item/4 sets a one-off reminder for no-schedule items" do
      household = GardenFixtures.household_fixture()
      member = GardenFixtures.member_fixture(household)
      section = GardenFixtures.section_fixture(household)

      item =
        GardenFixtures.care_item_fixture(section, %{
          name: "Quiet Bed",
          watering_interval_days: nil,
          next_due_on: nil
        })

      assert {:ok, updated_item} =
               Garden.soil_check_item(item, member, {:days, 6}, ~D[2026-03-27])

      assert updated_item.next_due_on == nil
      assert updated_item.manual_due_on == ~D[2026-04-02]
      assert updated_item.last_checked_on == ~D[2026-03-27]

      event = Repo.one!(from(care_event in CareEvent, where: care_event.care_item_id == ^item.id))

      assert event.event_type == :soil_checked
      assert event.previous_due_on == nil
      assert event.resulting_due_on == ~D[2026-04-02]
    end

    test "mark_item_needs_watering/4 keeps next_due_on and creates the event" do
      household = GardenFixtures.household_fixture()
      member = GardenFixtures.member_fixture(household)
      section = GardenFixtures.section_fixture(household)

      item =
        GardenFixtures.care_item_fixture(section, %{
          name: "Long Bed",
          next_due_on: ~D[2026-03-30]
        })

      assert {:ok, updated_item} =
               Garden.mark_item_needs_watering(
                 item,
                 member,
                 ~D[2026-03-28],
                 ~D[2026-03-27]
               )

      assert updated_item.next_due_on == ~D[2026-03-30]
      assert updated_item.manual_due_on == ~D[2026-03-28]
      assert updated_item.last_care_event_on == ~D[2026-03-27]

      event = Repo.one!(from(care_event in CareEvent, where: care_event.care_item_id == ^item.id))

      assert event.event_type == :manual_needs_watering
      assert event.manual_target_on == ~D[2026-03-28]
      assert event.previous_due_on == ~D[2026-03-30]
      assert event.resulting_due_on == ~D[2026-03-28]
    end

    test "mark_item_needs_watering/4 supports no-schedule items while setting manual due" do
      household = GardenFixtures.household_fixture()
      member = GardenFixtures.member_fixture(household)
      section = GardenFixtures.section_fixture(household)

      item =
        GardenFixtures.care_item_fixture(section, %{
          name: "Muted Mint",
          watering_interval_days: nil,
          next_due_on: nil
        })

      assert {:ok, updated_item} =
               Garden.mark_item_needs_watering(
                 item,
                 member,
                 ~D[2026-03-28],
                 ~D[2026-03-27]
               )

      assert updated_item.next_due_on == nil
      assert updated_item.manual_due_on == ~D[2026-03-28]
    end

    test "mark_item_needs_watering/4 returns no_state_change when the due date is already the same" do
      household = GardenFixtures.household_fixture()
      member = GardenFixtures.member_fixture(household)
      section = GardenFixtures.section_fixture(household)

      item =
        GardenFixtures.care_item_fixture(section, %{
          name: "Already Today",
          watering_interval_days: 3,
          next_due_on: ~D[2026-03-30],
          manual_due_on: ~D[2026-03-28]
        })

      assert Garden.mark_item_needs_watering(item, member, ~D[2026-03-28], ~D[2026-03-27]) ==
               {:error, :no_state_change}

      assert Repo.aggregate(CareEvent, :count) == 0
    end

    test "clear_schedule_item/3 removes recurrence and due dates while preserving care history" do
      household = GardenFixtures.household_fixture()
      member = GardenFixtures.member_fixture(household)
      section = GardenFixtures.section_fixture(household)

      item =
        GardenFixtures.care_item_fixture(section, %{
          name: "Quiet Mulberry",
          next_due_on: ~D[2026-03-30],
          manual_due_on: ~D[2026-03-28],
          last_watered_on: ~D[2026-03-20],
          last_checked_on: ~D[2026-03-24]
        })

      assert {:ok, updated_item} = Garden.clear_schedule_item(item, member, ~D[2026-03-27])

      assert updated_item.watering_interval_days == nil
      assert updated_item.next_due_on == nil
      assert updated_item.manual_due_on == nil
      assert updated_item.last_watered_on == ~D[2026-03-20]
      assert updated_item.last_checked_on == ~D[2026-03-24]
      assert updated_item.last_care_event_on == ~D[2026-03-27]

      event = Repo.one!(from(care_event in CareEvent, where: care_event.care_item_id == ^item.id))

      assert event.event_type == :schedule_changed
      assert event.previous_due_on == ~D[2026-03-28]
      assert event.resulting_due_on == nil
    end

    test "clear_schedule_item/3 returns no_state_change when an item is already no schedule" do
      household = GardenFixtures.household_fixture()
      member = GardenFixtures.member_fixture(household)
      section = GardenFixtures.section_fixture(household)

      item =
        GardenFixtures.care_item_fixture(section, %{
          name: "Already Quiet",
          watering_interval_days: nil,
          next_due_on: nil
        })

      assert Garden.clear_schedule_item(item, member, ~D[2026-03-28]) ==
               {:error, :no_state_change}

      assert Repo.aggregate(CareEvent, :count) == 0
    end

    test "subsequent commands clear manual due dates" do
      household = GardenFixtures.household_fixture()
      member = GardenFixtures.member_fixture(household)
      section = GardenFixtures.section_fixture(household)

      item =
        GardenFixtures.care_item_fixture(section, %{
          name: "Mulberry",
          watering_interval_days: 2,
          next_due_on: ~D[2026-03-29],
          manual_due_on: ~D[2026-03-28]
        })

      assert {:ok, updated_item} =
               Garden.soil_check_item(item, member, {:days, 1}, ~D[2026-03-27])

      assert updated_item.manual_due_on == nil
      assert updated_item.next_due_on == ~D[2026-03-29]
    end

    test "normalizes command validation failures" do
      household = GardenFixtures.household_fixture()
      member = GardenFixtures.member_fixture(household)
      section = GardenFixtures.section_fixture(household)
      item = GardenFixtures.care_item_fixture(section, %{name: "Parsley"})

      assert Garden.soil_check_item(item, member, {:days, 0}, ~D[2026-03-27]) ==
               {:error, :invalid_postpone_days}

      assert Garden.mark_item_needs_watering(item, member, ~D[2026-03-26], ~D[2026-03-27]) ==
               {:error, :invalid_manual_target}
    end

    test "rejects member and item household mismatches" do
      household = GardenFixtures.household_fixture()
      other_household = GardenFixtures.household_fixture()
      member = GardenFixtures.member_fixture(other_household)
      section = GardenFixtures.section_fixture(household)
      item = GardenFixtures.care_item_fixture(section, %{name: "Rose"})

      assert Garden.water_item(item, member, ~D[2026-03-27]) ==
               {:error, :member_household_mismatch}
    end

    test "returns :stale on optimistic lock conflicts and does not duplicate events" do
      household = GardenFixtures.household_fixture()
      member = GardenFixtures.member_fixture(household)
      section = GardenFixtures.section_fixture(household)

      item =
        GardenFixtures.care_item_fixture(section, %{
          name: "Mint",
          watering_interval_days: 3,
          next_due_on: ~D[2026-03-27]
        })

      stale_copy = Garden.get_item!(household, item.id)
      fresh_copy = Garden.get_item!(household, item.id)

      assert {:ok, _updated_item} = Garden.water_item(fresh_copy, member, ~D[2026-03-27])
      assert Garden.water_item(stale_copy, member, ~D[2026-03-27]) == {:error, :stale}

      assert Repo.aggregate(CareEvent, :count) == 1
    end
  end
end
