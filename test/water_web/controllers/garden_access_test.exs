defmodule WaterWeb.GardenAccessTest do
  use WaterWeb.ConnCase, async: true

  alias Water.GardenFixtures

  @active_member_session_key "active_member_id"

  describe "GET /" do
    test "returns 401 without basic auth" do
      conn = get(unauthenticated_conn(), ~p"/")

      assert response(conn, 401)
    end

    test "authenticates member A and stores the active member session" do
      household = GardenFixtures.default_household_fixture()
      member = GardenFixtures.member_fixture(household, %{name: "A"})

      conn =
        build_conn()
        |> authenticated_conn("a")
        |> get(~p"/")

      html = html_response(conn, 200)

      assert html =~ "id=\"garden-shell\""
      assert get_session(conn, @active_member_session_key) == member.id
    end

    test "authenticates member J and stores the active member session" do
      household = GardenFixtures.default_household_fixture()
      member = GardenFixtures.member_fixture(household, %{name: "J"})

      conn =
        build_conn()
        |> authenticated_conn("j")
        |> get(~p"/")

      assert html_response(conn, 200)
      assert get_session(conn, @active_member_session_key) == member.id
    end

    test "returns 401 when the configured username has no matching member" do
      household = GardenFixtures.default_household_fixture()
      _member = GardenFixtures.member_fixture(household, %{name: "A"})

      conn =
        build_conn()
        |> authenticated_conn("j")
        |> get(~p"/")

      assert response(conn, 401)
    end

    test "returns 401 when the matching member is inactive" do
      household = GardenFixtures.default_household_fixture()
      _member = GardenFixtures.member_fixture(household, %{name: "J", active: false})

      conn =
        build_conn()
        |> authenticated_conn("j")
        |> get(~p"/")

      assert response(conn, 401)
    end
  end

  describe "removed demo routes" do
    test "returns 404 for /notes", %{conn: conn} do
      household = GardenFixtures.default_household_fixture()
      _member = GardenFixtures.member_fixture(household, %{name: "A"})

      conn = get(conn, "/notes")

      assert html_response(conn, 404)
    end
  end
end
