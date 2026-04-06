defmodule WaterWeb.GardenCareActionsLiveTest do
  use WaterWeb.ConnCase, async: true

  import Ecto.Query
  import Phoenix.LiveViewTest
  import WaterWeb.GardenLiveTestHelpers

  alias Water.Garden.CareEvent
  alias Water.Households
  alias Water.Repo

  describe "water mode" do
    test "escape switches water mode back to browse", %{conn: conn} do
      _board = seed_board()

      {:ok, view, _html} = live(conn, ~p"/")

      render_click(element(view, "#tool-dock-desktop-water"))
      assert has_element?(view, "#tool-dock-desktop-water[aria-pressed='true']")

      render_keydown(view, "escape_tool_mode", %{"key" => "Escape"})

      assert has_element?(view, "#tool-dock-desktop-browse[aria-pressed='true']")
      refute has_element?(view, "#tool-dock-desktop-water[aria-pressed='true']")
    end

    test "watering a board tile refreshes it in place and keeps water mode active", %{conn: conn} do
      %{today_item: today_item} = seed_board()

      {:ok, view, _html} = live(conn, ~p"/")

      render_click(element(view, "#tool-dock-desktop-water"))
      render_click(element(view, "#section-item-tile-#{today_item.id}"))

      assert has_element?(view, "#tool-dock-desktop-water[aria-pressed='true']")
      assert has_element?(view, "#section-item-tile-#{today_item.id}-feedback", "Watered")
      refute has_element?(view, "#today-panel-item-#{today_item.id}")
    end

    test "clicking anywhere on a water-mode tile waters the item", %{conn: conn} do
      %{today_item: today_item} = seed_board()

      {:ok, view, _html} = live(conn, ~p"/")

      render_click(element(view, "#tool-dock-desktop-water"))
      render_click(element(view, "#section-item-tile-#{today_item.id}"))

      assert has_element?(view, "#tool-dock-desktop-water[aria-pressed='true']")
      assert has_element?(view, "#section-item-tile-#{today_item.id}-feedback", "Watered")
      refute has_element?(view, "#today-panel-item-#{today_item.id}")
    end

    test "watering a needs care tile updates the urgent list immediately", %{conn: conn} do
      %{manual_today_item: manual_today_item} = seed_board()

      {:ok, view, _html} = live(conn, ~p"/")

      render_click(element(view, "#tool-dock-desktop-water"))
      render_click(element(view, "#today-panel-item-#{manual_today_item.id}"))

      assert has_element?(view, "#tool-dock-desktop-water[aria-pressed='true']")
      refute has_element?(view, "#today-panel-item-#{manual_today_item.id}")
    end

    test "repeated watering shows explicit feedback without adding duplicate history", %{
      conn: conn
    } do
      %{today_item: today_item} = seed_board()

      {:ok, view, _html} = live(conn, ~p"/")

      render_click(element(view, "#tool-dock-desktop-water"))
      render_click(element(view, "#section-item-tile-#{today_item.id}"))

      assert has_element?(view, "#section-item-tile-#{today_item.id}-feedback", "Watered")

      render_click(element(view, "#section-item-tile-#{today_item.id}"))

      assert has_element?(
               view,
               "#section-item-tile-#{today_item.id}-feedback",
               "Already watered today"
             )

      assert Repo.aggregate(
               from(care_event in CareEvent, where: care_event.care_item_id == ^today_item.id),
               :count,
               :id
             ) == 1
    end

    test "detail modal watering refreshes the modal and board without closing it", %{conn: conn} do
      %{today_item: today_item} = seed_board()

      {:ok, view, _html} = live(conn, ~p"/")

      render_click(element(view, "#section-item-tile-#{today_item.id}"))
      assert_patch(view, ~p"/items/#{today_item.id}")

      render_click(element(view, "#item-detail-water"))

      assert has_element?(view, "#item-detail-modal")
      assert has_element?(view, "#item-detail-feedback", "Watered")
      assert has_element?(view, "#item-detail-history")
      assert has_element?(view, "#item-detail-history", "Watered")
      refute has_element?(view, "#today-panel-item-#{today_item.id}")
      refute has_element?(view, "#item-detail-last-watered", "Not yet recorded")
    end

    test "detail modal watering on a no-schedule item updates history without adding a due date",
         %{
           conn: conn
         } do
      %{no_schedule_item: no_schedule_item} = seed_board()

      {:ok, view, _html} = live(conn, ~p"/")

      render_click(element(view, "#section-item-tile-#{no_schedule_item.id}"))
      assert_patch(view, ~p"/items/#{no_schedule_item.id}")

      assert has_element?(view, "#item-detail-clear-schedule")

      render_click(element(view, "#item-detail-water"))

      assert has_element?(view, "#item-detail-modal")
      assert has_element?(view, "#item-detail-feedback", "Watered")
      assert has_element?(view, "#item-detail-history", "Watered")
      assert has_element?(view, "#item-detail-due", "No schedule")
      assert has_element?(view, "#item-detail-clear-schedule")
      refute has_element?(view, "#item-detail-last-watered", "Not yet recorded")
    end

    test "detail modal clear schedule refreshes the modal and removes the item from urgent views",
         %{
           conn: conn
         } do
      %{today_item: today_item} = seed_board()

      {:ok, view, _html} = live(conn, ~p"/")

      render_click(element(view, "#section-item-tile-#{today_item.id}"))
      assert_patch(view, ~p"/items/#{today_item.id}")

      render_click(element(view, "#item-detail-clear-schedule"))

      assert has_element?(view, "#item-detail-modal")
      assert has_element?(view, "#item-detail-feedback", "No schedule")
      assert has_element?(view, "#item-detail-history")
      assert has_element?(view, "#item-detail-history", "Schedule changed")
      assert has_element?(view, "#item-detail-history", "Cleared schedule")
      assert has_element?(view, "#item-detail-due", "No schedule")
      refute has_element?(view, "#today-panel-item-#{today_item.id}")
    end
  end

  describe "soil check mode" do
    test "escape closes the chooser and switches soil check back to browse", %{conn: conn} do
      %{overdue_item: overdue_item} = seed_board()

      {:ok, view, _html} = live(conn, ~p"/")

      render_click(element(view, "#tool-dock-desktop-soil-check"))
      render_click(element(view, "#section-item-tile-#{overdue_item.id}"))

      assert has_element?(view, "#tool-dock-desktop-soil-check[aria-pressed='true']")
      assert has_element?(view, "#care-action-modal")

      render_keydown(view, "escape_tool_mode", %{"key" => "Escape"})

      assert has_element?(view, "#tool-dock-desktop-soil-check[aria-pressed='true']")
      refute has_element?(view, "#care-action-modal")
    end

    test "opens the chooser from a tile, supports usual interval, and stays in mode", %{
      conn: conn
    } do
      %{overdue_item: overdue_item} = seed_board()

      {:ok, view, _html} = live(conn, ~p"/")

      render_click(element(view, "#tool-dock-desktop-soil-check"))
      render_click(element(view, "#section-item-tile-#{overdue_item.id}"))

      assert has_element?(view, "#care-action-modal")

      render_click(element(view, "#care-action-modal-soil-usual"))

      assert has_element?(view, "#tool-dock-desktop-soil-check[aria-pressed='true']")
      assert has_element?(view, "#section-item-tile-#{overdue_item.id}-feedback", "+3d")
      refute has_element?(view, "#care-action-modal")
    end

    test "close button dismisses the shared care action modal", %{conn: conn} do
      %{overdue_item: overdue_item} = seed_board()

      {:ok, view, _html} = live(conn, ~p"/")

      render_click(element(view, "#tool-dock-desktop-soil-check"))
      render_click(element(view, "#section-item-tile-#{overdue_item.id}"))

      assert has_element?(view, "#care-action-modal")

      render_click(element(view, "#care-action-modal-close"))

      refute has_element?(view, "#care-action-modal")
      assert has_element?(view, "#tool-dock-desktop-soil-check[aria-pressed='true']")
    end

    test "custom soil check validates inline and saves custom days", %{conn: conn} do
      %{overdue_item: overdue_item} = seed_board()

      {:ok, view, _html} = live(conn, ~p"/")

      render_click(element(view, "#tool-dock-desktop-soil-check"))
      render_click(element(view, "#section-item-tile-#{overdue_item.id}"))

      render_click(element(view, "#care-action-modal-soil-custom-toggle"))

      view
      |> form("#care-action-modal-soil-custom-form",
        schedule_watering: %{"days" => "0"}
      )
      |> render_submit()

      assert has_element?(
               view,
               "#care-action-modal-soil-error",
               "Enter a positive number of days."
             )

      view
      |> form("#care-action-modal-soil-custom-form",
        schedule_watering: %{"days" => "2"}
      )
      |> render_submit()

      assert has_element?(view, "#tool-dock-desktop-soil-check[aria-pressed='true']")
      assert has_element?(view, "#section-item-tile-#{overdue_item.id}-feedback", "+2d")
      refute has_element?(view, "#care-action-modal")
    end

    test "date soil check validates inline and saves the chosen due date", %{conn: conn} do
      %{overdue_item: overdue_item} = seed_board()

      {:ok, view, _html} = live(conn, ~p"/")
      today = household_today(Households.get_default_household!())

      render_click(element(view, "#tool-dock-desktop-soil-check"))
      render_click(element(view, "#section-item-tile-#{overdue_item.id}"))

      render_click(element(view, "#care-action-modal-soil-date-toggle"))

      invalid_date = Date.add(today, -2) |> Date.to_iso8601()

      view
      |> form("#care-action-modal-soil-date-form",
        schedule_watering: %{"target_on" => invalid_date}
      )
      |> render_submit()

      assert has_element?(
               view,
               "#care-action-modal-soil-error",
               "Choose a date after the current due date."
             )

      valid_date = Date.add(today, 4) |> Date.to_iso8601()

      view
      |> form("#care-action-modal-soil-date-form",
        schedule_watering: %{"target_on" => valid_date}
      )
      |> render_submit()

      assert has_element?(view, "#tool-dock-desktop-soil-check[aria-pressed='true']")
      assert has_element?(view, "#section-item-tile-#{overdue_item.id}-feedback", "+5d")
      refute has_element?(view, "#care-action-modal")
    end

    test "detail modal schedule watering opens one menu and supports usual interval", %{
      conn: conn
    } do
      %{overdue_item: overdue_item} = seed_board()

      {:ok, view, _html} = live(conn, ~p"/")

      render_click(element(view, "#section-item-tile-#{overdue_item.id}"))
      assert_patch(view, ~p"/items/#{overdue_item.id}")

      render_click(element(view, "#item-detail-schedule-watering"))

      assert has_element?(view, "#care-action-modal")
      assert has_element?(view, "#care-action-modal-schedule-today")
      assert has_element?(view, "#care-action-modal-schedule-tomorrow")
      assert has_element?(view, "#care-action-modal-schedule-usual")
      assert has_element?(view, "#care-action-modal-schedule-custom-toggle")
      assert has_element?(view, "#care-action-modal-schedule-date-toggle")

      render_click(element(view, "#care-action-modal-schedule-usual"))

      assert has_element?(view, "#item-detail-modal")
      assert has_element?(view, "#item-detail-feedback", "+3d")
      assert has_element?(view, "#section-item-tile-#{overdue_item.id}-feedback", "+3d")
      assert has_element?(view, "#item-detail-history")
      assert has_element?(view, "#item-detail-history", "Soil checked")
      assert has_element?(view, "#item-detail-history", "+3 days")
    end
  end

  describe "manual needs water mode" do
    test "escape switches needs water back to browse", %{conn: conn} do
      _board = seed_board()

      {:ok, view, _html} = live(conn, ~p"/")

      render_click(element(view, "#tool-dock-desktop-needs-water"))

      assert has_element?(view, "#tool-dock-desktop-needs-water[aria-pressed='true']")

      render_keydown(view, "escape_tool_mode", %{"key" => "Escape"})

      assert has_element?(view, "#tool-dock-desktop-browse[aria-pressed='true']")
      refute has_element?(view, "#tool-dock-desktop-needs-water[aria-pressed='true']")
    end

    test "clicking a section tile in needs water mode marks it for today and keeps mode active",
         %{conn: conn} do
      %{later_item: later_item} = seed_board()

      {:ok, view, _html} = live(conn, ~p"/")

      render_click(element(view, "#tool-dock-desktop-needs-water"))
      render_click(element(view, "#section-item-tile-#{later_item.id}"))

      assert has_element?(
               view,
               "#section-item-tile-#{later_item.id}-feedback",
               "Needs Watering Today"
             )

      assert has_element?(
               view,
               "#today-panel-item-#{later_item.id}-feedback",
               "Needs Watering Today"
             )

      assert has_element?(view, "#tool-dock-desktop-needs-water[aria-pressed='true']")
      assert has_element?(view, "#today-panel-item-#{later_item.id}")
    end

    test "clicking a needs care tile in needs water mode applies the direct mark in place", %{
      conn: conn
    } do
      %{manual_today_item: manual_today_item} = seed_board()

      {:ok, view, _html} = live(conn, ~p"/")

      render_click(element(view, "#tool-dock-desktop-needs-water"))
      render_click(element(view, "#today-panel-item-#{manual_today_item.id}"))

      assert has_element?(view, "#tool-dock-desktop-needs-water[aria-pressed='true']")
      assert has_element?(view, "#today-panel-item-#{manual_today_item.id}")
      assert Repo.aggregate(CareEvent, :count, :id) == 0
    end

    test "detail modal schedule watering supports tomorrow reminders", %{
      conn: conn
    } do
      %{later_item: later_item} = seed_board()

      {:ok, view, _html} = live(conn, ~p"/")
      tomorrow = Households.get_default_household!() |> household_today() |> Date.add(1)
      tomorrow_label = "Needs Watering on #{Calendar.strftime(tomorrow, "%b %-d")}"

      render_click(element(view, "#section-item-tile-#{later_item.id}"))
      assert_patch(view, ~p"/items/#{later_item.id}")

      render_click(element(view, "#item-detail-schedule-watering"))
      assert has_element?(view, "#care-action-modal")
      assert has_element?(view, "#care-action-modal-schedule-tomorrow")

      render_click(element(view, "#care-action-modal-schedule-tomorrow"))

      assert has_element?(view, "#item-detail-modal")
      assert has_element?(view, "#item-detail-feedback", tomorrow_label)
      assert has_element?(view, "#section-item-tile-#{later_item.id}-feedback", tomorrow_label)
      assert has_element?(view, "#item-detail-history")
      assert has_element?(view, "#item-detail-history", "Marked needs water")
      assert has_element?(view, "#tool-dock-desktop-browse[aria-pressed='true']")
      refute has_element?(view, "#today-panel-item-#{later_item.id}")
    end

    test "detail modal schedule watering keeps the action open when the picked due date is unchanged",
         %{
           conn: conn
         } do
      %{today_item: today_item} = seed_board()

      {:ok, view, _html} = live(conn, ~p"/")

      render_click(element(view, "#section-item-tile-#{today_item.id}"))
      assert_patch(view, ~p"/items/#{today_item.id}")

      render_click(element(view, "#item-detail-schedule-watering"))
      assert has_element?(view, "#care-action-modal")
      assert Repo.aggregate(CareEvent, :count, :id) == 0

      render_click(element(view, "#care-action-modal-schedule-today"))

      refute has_element?(view, "#care-action-modal")
      assert Repo.aggregate(CareEvent, :count, :id) == 0
      refute has_element?(view, "#item-detail-history", "Marked needs water")
    end

    test "detail modal schedule watering custom days validates inline and saves", %{
      conn: conn
    } do
      %{overdue_item: overdue_item} = seed_board()

      {:ok, view, _html} = live(conn, ~p"/")

      render_click(element(view, "#section-item-tile-#{overdue_item.id}"))
      assert_patch(view, ~p"/items/#{overdue_item.id}")

      render_click(element(view, "#item-detail-schedule-watering"))
      assert has_element?(view, "#care-action-modal")

      render_click(element(view, "#care-action-modal-schedule-custom-toggle"))

      view
      |> form("#care-action-modal-schedule-custom-form",
        schedule_watering: %{"days" => "0"}
      )
      |> render_submit()

      assert has_element?(
               view,
               "#care-action-modal-schedule-error",
               "Enter a positive number of days."
             )

      view
      |> form("#care-action-modal-schedule-custom-form",
        schedule_watering: %{"days" => "2"}
      )
      |> render_submit()

      assert has_element?(view, "#item-detail-modal")
      assert has_element?(view, "#item-detail-feedback", "+2d")
      assert has_element?(view, "#section-item-tile-#{overdue_item.id}-feedback", "+2d")
      assert has_element?(view, "#item-detail-history")
      assert has_element?(view, "#item-detail-history", "Soil checked")
      assert has_element?(view, "#item-detail-history", "+2 days")
      assert has_element?(view, "#tool-dock-desktop-browse[aria-pressed='true']")
      refute has_element?(view, "#today-panel-item-#{overdue_item.id}")
    end

    test "detail modal schedule watering pick date validates inline and saves the exact due date",
         %{
           conn: conn
         } do
      %{overdue_item: overdue_item} = seed_board()

      {:ok, view, _html} = live(conn, ~p"/")
      today = household_today(Households.get_default_household!())

      render_click(element(view, "#section-item-tile-#{overdue_item.id}"))
      assert_patch(view, ~p"/items/#{overdue_item.id}")

      render_click(element(view, "#item-detail-schedule-watering"))
      assert has_element?(view, "#care-action-modal")

      render_click(element(view, "#care-action-modal-schedule-date-toggle"))

      invalid_date = Date.add(today, -2) |> Date.to_iso8601()

      view
      |> form("#care-action-modal-schedule-date-form",
        schedule_watering: %{"target_on" => invalid_date}
      )
      |> render_submit()

      assert has_element?(
               view,
               "#care-action-modal-schedule-error",
               "Choose a date after the current due date."
             )

      valid_date = Date.add(today, 4)

      view
      |> form("#care-action-modal-schedule-date-form",
        schedule_watering: %{"target_on" => Date.to_iso8601(valid_date)}
      )
      |> render_submit()

      assert has_element?(view, "#item-detail-modal")
      assert has_element?(view, "#item-detail-feedback", "+5d")
      assert has_element?(view, "#section-item-tile-#{overdue_item.id}-feedback", "+5d")
      assert has_element?(view, "#item-detail-history")
      assert has_element?(view, "#item-detail-history", "Soil checked")
      assert has_element?(view, "#item-detail-history", "+5 days")
      assert has_element?(view, "#tool-dock-desktop-browse[aria-pressed='true']")
      refute has_element?(view, "#today-panel-item-#{overdue_item.id}")
    end
  end
end
