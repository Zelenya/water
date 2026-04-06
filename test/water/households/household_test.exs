defmodule Water.Households.HouseholdTest do
  use Water.DataCase, async: true

  alias Water.Households.Household
  alias Water.GardenFixtures

  describe "changeset/2" do
    test "rejects an invalid time zone" do
      changeset =
        Household.changeset(%Household{}, %{
          name: "Water House",
          slug: "default",
          timezone: "Mars/Olympus_Mons"
        })

      assert "must be a valid IANA time zone" in errors_on(changeset).timezone
    end

    test "enforces slug uniqueness" do
      _household = GardenFixtures.household_fixture(%{slug: "default-household"})

      {:error, changeset} =
        %Household{}
        |> Household.changeset(%{
          name: "Another House",
          slug: "default-household",
          timezone: "America/Los_Angeles"
        })
        |> Repo.insert()

      assert "has already been taken" in errors_on(changeset).slug
    end
  end
end
