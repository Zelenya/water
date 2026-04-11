defmodule WaterWeb.GardenCommandLauncherLiveTest do
  use WaterWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import WaterWeb.GardenLiveTestHelpers

  alias Water.GardenFixtures

  describe "launcher shell" do
    test "renders header triggers and opens the launcher", %{conn: conn} do
      _board = seed_board()
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "#garden-command-launcher-trigger")
      assert has_element?(view, "#garden-command-launcher-trigger-mobile")

      render_click(element(view, "#garden-command-launcher-trigger"))

      assert has_element?(view, "#garden-command-launcher")
      assert has_element?(view, "#garden-command-launcher-commands")
      assert has_element?(view, "#garden-command-launcher-results")
    end

    test "closes the launcher on backdrop click", %{conn: conn} do
      _board = seed_board()
      {:ok, view, _html} = live(conn, ~p"/")

      render_click(element(view, "#garden-command-launcher-trigger"))
      assert has_element?(view, "#garden-command-launcher")

      render_click(element(view, "#garden-command-launcher-backdrop"))
      refute has_element?(view, "#garden-command-launcher")
    end

    test "keeps launcher unavailable if detail modal is open", %{conn: conn} do
      %{overdue_item: overdue_item} = seed_board()
      {:ok, view, _html} = live(conn, ~p"/")

      render_click(element(view, "#section-item-tile-#{overdue_item.id}"))
      assert_patch(view, ~p"/items/#{overdue_item.id}")

      assert has_element?(view, "#item-detail-modal")
      refute has_element?(view, "#garden-command-launcher-trigger")
      refute has_element?(view, "#garden-command-launcher-trigger-mobile")
      refute has_element?(view, "#garden-command-launcher")
    end
  end

  describe "command launcher" do
    test "executes a tool command and closes the launcher", %{conn: conn} do
      _board = seed_board()
      {:ok, view, _html} = live(conn, ~p"/")

      render_click(element(view, "#garden-command-launcher-trigger"))
      render_click(element(view, "#garden-command-launcher-entry-command-tool-water"))

      refute has_element?(view, "#garden-command-launcher")
      assert has_element?(view, "#tool-dock-desktop-water[aria-pressed='true']")
    end

    test "executes add item from the launcher", %{conn: conn} do
      _board = seed_board()
      {:ok, view, _html} = live(conn, ~p"/")

      render_click(element(view, "#garden-command-launcher-trigger"))
      render_click(element(view, "#garden-command-launcher-entry-command-new-item"))

      assert_patch(view, ~p"/items/new")
      refute has_element?(view, "#garden-command-launcher")
      assert has_element?(view, "#item-form-modal")
    end

    test "selects an item result and opens item care modal", %{conn: conn} do
      household = GardenFixtures.default_household_fixture()
      _member = GardenFixtures.member_fixture(household, %{name: "A"})
      section = GardenFixtures.section_fixture(household, %{name: "Front", position: 0})
      item = GardenFixtures.care_item_fixture(section, %{name: "Chocolate Mint", position: 0})

      {:ok, view, _html} = live(conn, ~p"/")

      render_click(element(view, "#garden-command-launcher-trigger"))
      render_change(element(view, "#garden-command-launcher-form"), %{"query" => "front"})

      assert has_element?(view, "#garden-command-launcher-items")
      assert has_element?(view, "#garden-command-launcher-entry-item-#{item.id}", item.name)

      render_click(element(view, "#garden-command-launcher-entry-item-#{item.id}"))

      assert_patch(view, ~p"/items/#{item.id}")
      refute has_element?(view, "#garden-command-launcher")
      assert has_element?(view, "#item-detail-modal")
    end
  end
end
