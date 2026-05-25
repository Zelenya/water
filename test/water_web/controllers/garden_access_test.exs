defmodule WaterWeb.GardenAccessTest do
  use WaterWeb.ConnCase, async: true

  alias Water.GardenFixtures
  alias Water.Households

  @active_member_session_key "active_member_id"
  @auth_session_key "basic_auth_session"
  @logout_challenge_session_key "logout_challenge_pending"

  describe "GET /" do
    test "returns 401 without basic auth" do
      _household = GardenFixtures.default_household_fixture()

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
      assert html =~ "id=\"header-forget-browser\""
      assert html =~ "hero-arrow-right-on-rectangle-mini"
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

    test "accepts a valid existing session without basic auth" do
      household = GardenFixtures.default_household_fixture()
      member = GardenFixtures.member_fixture(household, %{name: "A"})

      conn =
        build_conn()
        |> authenticated_conn("a")
        |> get(~p"/")
        |> recycle(~w(accept accept-language))
        |> get(~p"/")

      assert html_response(conn, 200) =~ "id=\"garden-shell\""
      assert get_session(conn, @active_member_session_key) == member.id
    end

    test "returns 401 when the existing session belongs to an inactive member" do
      household = GardenFixtures.default_household_fixture()
      member = GardenFixtures.member_fixture(household, %{name: "A"})

      authenticated_conn =
        build_conn()
        |> authenticated_conn("a")
        |> get(~p"/")

      assert {:ok, %_{} = _inactive_member} = Households.update_member(member, %{active: false})

      conn =
        authenticated_conn
        |> recycle(~w(accept accept-language))
        |> get(~p"/")

      assert response(conn, 401)
    end

    test "logout clears the authenticated browser session" do
      household = GardenFixtures.default_household_fixture()
      _member = GardenFixtures.member_fixture(household, %{name: "A"})

      authenticated_conn =
        build_conn()
        |> authenticated_conn("a")
        |> get(~p"/")

      assert get_session(authenticated_conn, @auth_session_key)
      assert get_session(authenticated_conn, @active_member_session_key)

      conn =
        authenticated_conn
        |> recycle(~w(accept accept-language))
        |> delete(~p"/logout")

      assert redirected_to(conn) == ~p"/logout"
      refute get_session(conn, @auth_session_key)
      refute get_session(conn, @active_member_session_key)
      assert get_session(conn, @logout_challenge_session_key)
    end

    test "GET /logout challenges once after logout" do
      household = GardenFixtures.default_household_fixture()
      _member = GardenFixtures.member_fixture(household, %{name: "A"})

      conn =
        build_conn()
        |> authenticated_conn("a")
        |> get(~p"/")
        |> recycle(~w(accept accept-language))
        |> delete(~p"/logout")
        |> recycle(~w(accept accept-language))
        |> get(~p"/logout")

      assert response(conn, 401)
      assert get_resp_header(conn, "www-authenticate") == ["Basic realm=\"Water\""]
      refute get_session(conn, @logout_challenge_session_key)
    end

    test "GET /logout redirects home without a pending logout" do
      conn = get(unauthenticated_conn(), ~p"/logout")

      assert redirected_to(conn) == ~p"/"
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
