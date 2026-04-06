defmodule Water.Households.MemberTest do
  use Water.DataCase, async: true

  alias Water.GardenFixtures
  alias Water.Households.Member

  describe "create_changeset/3" do
    test "sets the household id from the parent household" do
      household = GardenFixtures.household_fixture()

      changeset =
        Member.create_changeset(%Member{}, household, %{
          name: "Sam",
          color: "#123456",
          active: true
        })

      assert Ecto.Changeset.get_field(changeset, :household_id) == household.id
    end

    test "enforces case-insensitive unique household names" do
      household = GardenFixtures.household_fixture()
      _member = GardenFixtures.member_fixture(household, %{name: "Sam"})

      {:error, changeset} =
        %Member{}
        |> Member.create_changeset(household, %{
          name: "sam",
          color: "#654321",
          active: true
        })
        |> Repo.insert()

      assert "has already been taken" in errors_on(changeset).name
    end
  end
end
