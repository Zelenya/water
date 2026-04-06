defmodule Water.HouseholdsTest do
  use Water.DataCase, async: true

  alias Water.GardenFixtures
  alias Water.Households
  alias Water.Households.{Household, Member}
  alias Water.Repo

  describe "default household" do
    test "bootstrap_default_household/0 is idempotent" do
      assert {:ok, household} = Households.bootstrap_default_household()
      assert {:ok, same_household} = Households.bootstrap_default_household()

      assert household.id == same_household.id
      assert Repo.aggregate(Household, :count) == 1
    end

    test "get_default_household!/0 finds the singleton household" do
      household = GardenFixtures.default_household_fixture()

      assert Households.get_default_household!().id == household.id
    end
  end

  describe "members" do
    test "list_members/1 returns the household members" do
      household = GardenFixtures.household_fixture()
      first = GardenFixtures.member_fixture(household, %{name: "First"})
      second = GardenFixtures.member_fixture(household, %{name: "Second"})

      assert Households.list_members(household)
             |> Enum.map(& &1.id)
             |> MapSet.new() == MapSet.new([first.id, second.id])
    end

    test "create_member/2 creates a member without position management" do
      household = GardenFixtures.household_fixture()

      assert {:ok, member} =
               Households.create_member(household, %{
                 name: "Sam",
                 color: "#123456"
               })

      assert member.name == "Sam"
      assert member.active
    end

    test "create_member/2 enforces case-insensitive name uniqueness" do
      household = GardenFixtures.household_fixture()
      _member = GardenFixtures.member_fixture(household, %{name: "Taylor"})

      assert {:error, changeset} =
               Households.create_member(household, %{
                 name: "taylor",
                 color: "#654321",
                 active: true
               })

      assert "has already been taken" in errors_on(changeset).name
    end

    test "update_member/2 can update member fields and respects case-insensitive uniqueness" do
      household = GardenFixtures.household_fixture()
      _first = GardenFixtures.member_fixture(household, %{name: "Alex"})
      second = GardenFixtures.member_fixture(household, %{name: "Jordan"})

      assert {:ok, %Member{} = updated_member} =
               Households.update_member(second, %{name: "Jordan Jr.", color: "#abcdef"})

      assert updated_member.name == "Jordan Jr."
      assert updated_member.color == "#abcdef"

      assert {:error, changeset} = Households.update_member(second, %{name: "alex"})
      assert "has already been taken" in errors_on(changeset).name
    end

    test "find_active_member_by_name/2 resolves case-insensitively and ignores inactive members" do
      household = GardenFixtures.household_fixture()
      active_member = GardenFixtures.member_fixture(household, %{name: "A"})
      _inactive_member = GardenFixtures.member_fixture(household, %{name: "J", active: false})

      assert Households.find_active_member_by_name(household, " a ").id == active_member.id
      assert Households.find_active_member_by_name(household, "j") == nil
      assert Households.find_active_member_by_name(household, "unknown") == nil
    end
  end
end
