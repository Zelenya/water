defmodule Water.Seeds.DemoGardenTest do
  use Water.DataCase, async: false

  import Ecto.Query

  alias Water.Garden
  alias Water.Garden.{CareItem, Schedule, Section}
  alias Water.GardenFixtures
  alias Water.Households.{Household, Member}
  alias Water.Repo
  alias Water.Seeds.DemoGarden

  test "loads the demo garden and leaves structure untouched on rerun" do
    assert %{household: household, members: members, sections: sections, items: items} =
             DemoGarden.seed!()

    assert household.slug == "default"
    assert household.timezone == "America/Los_Angeles"
    assert Enum.count(members) == 2
    assert Enum.count(sections) == 6
    assert Enum.count(items) == 24

    assert Repo.aggregate(Household, :count) == 1
    assert Repo.aggregate(Member, :count) == 2
    assert Repo.aggregate(Section, :count) == 6
    assert Repo.aggregate(CareItem, :count) == 24

    assert %{sections: rerun_sections, items: rerun_items} = DemoGarden.seed!()

    assert Repo.aggregate(Household, :count) == 1
    assert Repo.aggregate(Member, :count) == 2
    assert Repo.aggregate(Section, :count) == 6
    assert Repo.aggregate(CareItem, :count) == 24
    assert Enum.map(rerun_sections, & &1.id) == Enum.map(sections, & &1.id)
    assert Enum.map(rerun_items, & &1.id) == Enum.map(items, & &1.id)

    assert Enum.map(sections, & &1.name) == [
             "Front of the House",
             "Veggie beds",
             "Back of the House",
             "Nursery side",
             "Duck house",
             "Downhill"
           ]

    assert Enum.map(items, & &1.name) == [
             "Blueberry bed",
             "Front flowers",
             "Front hedge",
             "West bed",
             "East bed",
             "Veggie babies",
             "Bed raspberries",
             "Pears",
             "Native flower bed",
             "Long bed",
             "Herb bed",
             "Mulberry",
             "Honey berries",
             "Quince",
             "Cherries",
             "Peaches",
             "Nursery bed",
             "Nursery pots",
             "Raspberry and bushes",
             "Current",
             "Duck hedge",
             "Plum hedge",
             "Fruit trees",
             "Downhill bed"
           ]

    assert Repo.get_by!(CareItem, name: "Blueberry bed").watering_interval_days == 3
    assert Repo.get_by!(CareItem, name: "West bed").watering_interval_days == 3
    assert Repo.get_by!(CareItem, name: "Long bed").watering_interval_days == 3
    assert Repo.get_by!(CareItem, name: "Pears").watering_interval_days == 7
    assert Repo.get_by!(CareItem, name: "Mulberry").watering_interval_days == 7
    assert Repo.get_by!(CareItem, name: "Fruit trees").watering_interval_days == 7
    assert Repo.get_by!(CareItem, name: "Nursery pots").watering_interval_days == 3

    today = Date.utc_today()
    statuses = Enum.map(items, &Schedule.status(&1, today))

    assert :due_today in statuses
    assert :overdue in statuses
    assert :soon in statuses
  end

  test "reuses existing seeded members and preserves existing garden structure" do
    household = GardenFixtures.default_household_fixture()

    existing_member_a =
      GardenFixtures.member_fixture(household, %{name: "A", color: "#111111", active: false})

    existing_member_j =
      GardenFixtures.member_fixture(household, %{name: "J", color: "#222222", active: false})

    front =
      GardenFixtures.section_fixture(household, %{name: "Porch", position: 0})

    back =
      GardenFixtures.section_fixture(household, %{name: "Patio", position: 1})

    _front_item =
      GardenFixtures.care_item_fixture(front, %{name: "Placeholder Front", position: 0})

    _back_item_a =
      GardenFixtures.care_item_fixture(back, %{name: "Placeholder Back A", position: 0})

    _back_item_b =
      GardenFixtures.care_item_fixture(back, %{name: "Placeholder Back B", position: 1})

    assert %{members: members, sections: sections, items: items} = DemoGarden.seed!()

    assert Enum.map(members, & &1.id) == [existing_member_a.id, existing_member_j.id]
    assert Enum.map(members, & &1.name) == ["A", "J"]
    assert Enum.map(members, & &1.color) == ["#5B8DEF", "#F97316"]
    assert Enum.all?(members, & &1.active)

    assert Enum.map(sections, &{&1.name, &1.position}) == [
             {"Porch", 0},
             {"Patio", 1}
           ]

    assert Enum.map(items, &{&1.name, &1.position}) == [
             {"Placeholder Front", 0},
             {"Placeholder Back A", 0},
             {"Placeholder Back B", 1}
           ]

    assert Repo.aggregate(Member, :count) == 2
    assert Repo.aggregate(Section, :count) == 2
    assert Repo.aggregate(CareItem, :count) == 3
  end

  test "re-running seeds preserves live care state for existing seeded items" do
    %{members: members} = DemoGarden.seed!()
    member = Enum.find(members, &(&1.name == "A"))
    today = Date.utc_today()
    item = Repo.get_by!(CareItem, name: "Honey berries")

    assert {:ok, watered_item} = Garden.water_item(item, member, today)
    assert DemoGarden.seed!()

    reseeded_item = Repo.get_by!(CareItem, name: "Honey berries")

    latest_event =
      Repo.one!(
        from(care_event in Water.Garden.CareEvent,
          where: care_event.care_item_id == ^item.id and care_event.event_type == :watered,
          order_by: [desc: care_event.inserted_at],
          limit: 1
        )
      )

    assert reseeded_item.id == item.id
    assert reseeded_item.next_due_on == watered_item.next_due_on
    assert reseeded_item.manual_due_on == watered_item.manual_due_on
    assert reseeded_item.last_watered_on == today
    assert reseeded_item.last_care_event_on == today
    assert latest_event.resulting_due_on == reseeded_item.next_due_on
    assert Schedule.status(reseeded_item, today) == Schedule.status(watered_item, today)
  end

  test "existing seeded structure is preserved even when it differs from the latest canonical layout" do
    household = GardenFixtures.default_household_fixture()
    _member = GardenFixtures.member_fixture(household, %{name: "A", active: false})
    _other_member = GardenFixtures.member_fixture(household, %{name: "J", active: false})

    section =
      GardenFixtures.section_fixture(household, %{name: "Side of the House", position: 3})

    side_raspberry =
      GardenFixtures.care_item_fixture(section, %{
        name: "Side raspberry",
        position: 1,
        watering_interval_days: 3
      })

    assert %{sections: sections, items: items} = DemoGarden.seed!()

    assert Enum.map(sections, &{&1.id, &1.name, &1.position}) == [
             {section.id, "Side of the House", 3}
           ]

    assert Enum.map(items, &{&1.id, &1.name, &1.position}) == [
             {side_raspberry.id, "Side raspberry", 1}
           ]

    assert Enum.all?(Repo.all(Member), & &1.active)

    assert Enum.map(Repo.all(from(member in Member, order_by: [asc: member.name])), & &1.name) ==
             [
               "A",
               "J"
             ]
  end
end
