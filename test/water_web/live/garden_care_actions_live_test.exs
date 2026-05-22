defmodule WaterWeb.GardenCareActionsLiveTest do
  use WaterWeb.ConnCase, async: true

  import Ecto.Query
  import Phoenix.LiveViewTest
  import WaterWeb.GardenLiveTestHelpers

  alias Water.Garden.{CareEvent, CareItem}
  alias Water.GardenFixtures
  alias Water.Households
  alias Water.Repo
  alias WaterWeb.GardenLive.Navigation

  describe "water mode" do
    test "escape switches water mode back to browse", %{conn: conn} do
      _board = seed_board()

      {:ok, view, _html} = live(conn, ~p"/")

      select_tool(view, :water)
      assert_tool_active(view, :water)

      render_keydown(view, "escape_tool_mode", %{"key" => "Escape"})

      assert_tool_active(view, :browse)
      refute_tool_active(view, :water)
    end

    test "watering a board tile refreshes it in place and keeps water mode active", %{conn: conn} do
      %{today_item: today_item} = seed_board()

      {:ok, view, _html} = live(conn, ~p"/")

      select_tool(view, :water)
      render_click(element(view, "#section-item-tile-#{today_item.id}-button"))

      assert_tool_active(view, :water)
      assert_water_feedback(view, "section-item-tile-#{today_item.id}")
      refute has_element?(view, "#today-panel-item-#{today_item.id}")
    end

    test "watering a needs care tile updates the urgent list immediately", %{conn: conn} do
      %{manual_today_item: manual_today_item} = seed_board()

      {:ok, view, _html} = live(conn, ~p"/")

      select_tool(view, :water)
      render_click(element(view, "#today-panel-item-#{manual_today_item.id}-button"))

      assert_tool_active(view, :water)
      refute has_element?(view, "#today-panel-item-#{manual_today_item.id}")
    end

    test "repeated watering shows visual feedback without adding duplicate history", %{
      conn: conn
    } do
      %{today_item: today_item} = seed_board()

      {:ok, view, _html} = live(conn, ~p"/")

      select_tool(view, :water)
      render_click(element(view, "#section-item-tile-#{today_item.id}-button"))

      assert_water_feedback(view, "section-item-tile-#{today_item.id}")

      render_click(element(view, "#section-item-tile-#{today_item.id}-button"))

      assert_feedback_status(view, "section-item-tile-#{today_item.id}", :water)

      assert Repo.aggregate(
               from(care_event in CareEvent, where: care_event.care_item_id == ^today_item.id),
               :count,
               :id
             ) == 1
    end

    test "detail modal watering refreshes the modal and board without closing it", %{conn: conn} do
      %{today_item: today_item} = seed_board()

      {:ok, view, _html} = live(conn, ~p"/")

      open_item_detail(view, today_item)

      render_click(element(view, "#item-detail-water"))

      assert has_element?(view, "#item-detail-modal")
      assert_feedback_status(view, "item-detail", :water)
      assert has_element?(view, "#item-detail-last-watered.garden-detail-card-feedback")
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

      open_item_detail(view, no_schedule_item)

      assert has_element?(view, "#item-detail-clear-schedule")

      render_click(element(view, "#item-detail-water"))

      assert has_element?(view, "#item-detail-modal")
      assert_feedback_status(view, "item-detail", :water)
      assert has_element?(view, "#item-detail-last-watered.garden-detail-card-feedback")
      assert has_element?(view, "#item-detail-history", "Watered")
      assert has_element?(view, "#item-detail-due", "No schedule")
      assert has_element?(view, "#item-detail-clear-schedule")
      refute has_element?(view, "#item-detail-last-watered", "Not yet recorded")
    end

    test "watering a no-schedule item with a daily history opens the suggestion modal", %{
      conn: conn
    } do
      %{no_schedule_item: no_schedule_item} = seed_board()
      {member, today} = active_member_and_today()
      insert_waterings(no_schedule_item, member, [Date.add(today, -2), Date.add(today, -1)])

      {:ok, view, _html} = live(conn, ~p"/")

      select_tool(view, :water)
      render_click(element(view, "#section-item-tile-#{no_schedule_item.id}-button"))

      assert has_element?(view, "#schedule-suggestion-modal")
      assert has_element?(view, "#schedule-suggestion-item", no_schedule_item.name)
      assert has_element?(view, "#schedule-suggestion-current", "No schedule")
      assert has_element?(view, "#schedule-suggestion-proposed", "Every day")
      assert has_element?(view, "#schedule-suggestion-next-due")
    end

    test "accepting a schedule suggestion applies recurrence and records schedule history", %{
      conn: conn
    } do
      %{no_schedule_item: no_schedule_item} = seed_board()
      {member, today} = active_member_and_today()
      insert_waterings(no_schedule_item, member, [Date.add(today, -2), Date.add(today, -1)])

      {:ok, view, _html} = live(conn, ~p"/")

      select_tool(view, :water)
      render_click(element(view, "#section-item-tile-#{no_schedule_item.id}-button"))
      render_click(element(view, "#schedule-suggestion-accept"))

      refute has_element?(view, "#schedule-suggestion-modal")

      updated_item = Repo.get!(CareItem, no_schedule_item.id)
      assert updated_item.watering_interval_days == 1
      assert updated_item.next_due_on == Date.add(today, 1)

      assert Repo.aggregate(
               from(
                 care_event in CareEvent,
                 where:
                   care_event.care_item_id == ^no_schedule_item.id and
                     care_event.event_type == :schedule_changed
               ),
               :count,
               :id
             ) == 1
    end

    test "dismissing a schedule suggestion leaves the schedule unchanged", %{conn: conn} do
      %{no_schedule_item: no_schedule_item} = seed_board()
      {member, today} = active_member_and_today()
      insert_waterings(no_schedule_item, member, [Date.add(today, -2), Date.add(today, -1)])

      {:ok, view, _html} = live(conn, ~p"/")

      select_tool(view, :water)
      render_click(element(view, "#section-item-tile-#{no_schedule_item.id}-button"))
      render_click(element(view, "#schedule-suggestion-dismiss"))

      refute has_element?(view, "#schedule-suggestion-modal")

      updated_item = Repo.get!(CareItem, no_schedule_item.id)
      assert updated_item.watering_interval_days == nil
      assert updated_item.next_due_on == nil
    end

    test "detail modal watering keeps detail open and shows the suggestion overlay", %{conn: conn} do
      %{no_schedule_item: no_schedule_item} = seed_board()
      {member, today} = active_member_and_today()
      insert_waterings(no_schedule_item, member, [Date.add(today, -2), Date.add(today, -1)])

      {:ok, view, _html} = live(conn, ~p"/")

      open_item_detail(view, no_schedule_item)
      render_click(element(view, "#item-detail-water"))

      assert has_element?(view, "#item-detail-modal")
      assert has_element?(view, "#schedule-suggestion-modal")
      assert has_element?(view, "#item-detail-history", "Watered")
    end

    test "water all does not open schedule suggestions", %{conn: conn} do
      %{no_schedule_item: no_schedule_item} = seed_board()
      {member, today} = active_member_and_today()
      insert_waterings(no_schedule_item, member, [Date.add(today, -2), Date.add(today, -1)])

      {:ok, view, _html} = live(conn, ~p"/")

      render_click(element(view, "#garden-command-launcher-trigger"))
      render_click(element(view, "#garden-command-launcher-entry-command-rain"))

      refute has_element?(view, "#schedule-suggestion-modal")
    end

    test "detail modal clear schedule refreshes the modal and removes the item from urgent views",
         %{
           conn: conn
         } do
      %{today_item: today_item} = seed_board()

      {:ok, view, _html} = live(conn, ~p"/")

      open_item_detail(view, today_item)

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

      select_tool(view, :soil_check)
      render_click(element(view, "#section-item-tile-#{overdue_item.id}-button"))

      assert_tool_active(view, :soil_check)
      assert has_element?(view, "#care-action-modal")

      render_keydown(view, "escape_tool_mode", %{"key" => "Escape"})

      assert_tool_active(view, :soil_check)
      refute has_element?(view, "#care-action-modal")
    end

    test "opens the chooser from a tile, supports usual interval, and stays in mode", %{
      conn: conn
    } do
      %{overdue_item: overdue_item} = seed_board()

      {:ok, view, _html} = live(conn, ~p"/")

      select_tool(view, :soil_check)
      render_click(element(view, "#section-item-tile-#{overdue_item.id}-button"))

      assert has_element?(view, "#care-action-modal")

      render_click(element(view, "#care-action-modal-soil-usual"))

      assert_tool_active(view, :soil_check)
      assert has_element?(view, "#section-item-tile-#{overdue_item.id}-feedback", "+3d")
      assert_default_feedback(view, "section-item-tile-#{overdue_item.id}")
      refute has_element?(view, "#care-action-modal")
    end

    test "close button dismisses the shared care action modal", %{conn: conn} do
      %{overdue_item: overdue_item} = seed_board()

      {:ok, view, _html} = live(conn, ~p"/")

      select_tool(view, :soil_check)
      render_click(element(view, "#section-item-tile-#{overdue_item.id}-button"))

      assert has_element?(view, "#care-action-modal")

      render_click(element(view, "#care-action-modal-close"))

      refute has_element?(view, "#care-action-modal")
      assert has_element?(view, "#tool-dock-desktop-soil-check[aria-pressed='true']")
    end

    test "custom soil check validates inline and saves custom days", %{conn: conn} do
      %{overdue_item: overdue_item} = seed_board()

      {:ok, view, _html} = live(conn, ~p"/")

      select_tool(view, :soil_check)
      render_click(element(view, "#section-item-tile-#{overdue_item.id}-button"))

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

      assert_tool_active(view, :soil_check)
      assert has_element?(view, "#section-item-tile-#{overdue_item.id}-feedback", "+2d")
      refute has_element?(view, "#care-action-modal")
    end

    test "date soil check validates inline and saves the chosen due date", %{conn: conn} do
      %{overdue_item: overdue_item} = seed_board()

      {:ok, view, _html} = live(conn, ~p"/")
      today = Navigation.household_today(Households.get_default_household!())

      select_tool(view, :soil_check)
      render_click(element(view, "#section-item-tile-#{overdue_item.id}-button"))

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

      assert_tool_active(view, :soil_check)
      assert has_element?(view, "#section-item-tile-#{overdue_item.id}-feedback", "+5d")
      refute has_element?(view, "#care-action-modal")
    end

    test "detail modal schedule watering opens one menu and supports usual interval", %{
      conn: conn
    } do
      %{overdue_item: overdue_item} = seed_board()

      {:ok, view, _html} = live(conn, ~p"/")

      open_item_detail(view, overdue_item)

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
      assert_feedback_status(view, "item-detail", :default)
      assert has_element?(view, "#item-detail-due.garden-detail-card-feedback")
      assert has_element?(view, "#section-item-tile-#{overdue_item.id}-feedback", "+3d")
      assert_default_feedback(view, "section-item-tile-#{overdue_item.id}")
      assert has_element?(view, "#item-detail-history")
      assert has_element?(view, "#item-detail-history", "Soil checked")
      assert has_element?(view, "#item-detail-history", "+3 days")
    end
  end

  describe "manual needs water mode" do
    test "escape switches needs water back to browse", %{conn: conn} do
      _board = seed_board()

      {:ok, view, _html} = live(conn, ~p"/")

      select_tool(view, :manual_needs_watering)

      assert_tool_active(view, :manual_needs_watering)

      render_keydown(view, "escape_tool_mode", %{"key" => "Escape"})

      assert_tool_active(view, :browse)
      refute_tool_active(view, :manual_needs_watering)
    end

    test "clicking a section tile in needs water mode marks it for today and keeps mode active",
         %{conn: conn} do
      %{later_item: later_item} = seed_board()

      {:ok, view, _html} = live(conn, ~p"/")

      select_tool(view, :manual_needs_watering)
      render_click(element(view, "#section-item-tile-#{later_item.id}-button"))

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

      assert_tool_active(view, :manual_needs_watering)
      assert has_element?(view, "#today-panel-item-#{later_item.id}")
    end

    test "clicking a needs care tile in needs water mode applies the direct mark in place", %{
      conn: conn
    } do
      %{manual_today_item: manual_today_item} = seed_board()

      {:ok, view, _html} = live(conn, ~p"/")

      select_tool(view, :manual_needs_watering)
      render_click(element(view, "#today-panel-item-#{manual_today_item.id}-button"))

      assert_tool_active(view, :manual_needs_watering)
      assert has_element?(view, "#today-panel-item-#{manual_today_item.id}")
      assert Repo.aggregate(CareEvent, :count, :id) == 0
    end

    test "detail modal schedule watering supports tomorrow reminders", %{
      conn: conn
    } do
      %{later_item: later_item} = seed_board()

      {:ok, view, _html} = live(conn, ~p"/")

      tomorrow =
        Households.get_default_household!()
        |> Navigation.household_today()
        |> Date.add(1)

      tomorrow_label = "Needs Watering on #{Calendar.strftime(tomorrow, "%b %-d")}"

      open_item_detail(view, later_item)

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

      open_item_detail(view, today_item)

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

      open_item_detail(view, overdue_item)

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
      today = Navigation.household_today(Households.get_default_household!())

      open_item_detail(view, overdue_item)

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

  defp select_tool(view, mode) do
    render_click(element(view, tool_selector(mode)))
  end

  defp assert_tool_active(view, mode) do
    assert has_element?(view, "#{tool_selector(mode)}[aria-pressed='true']")
  end

  defp refute_tool_active(view, mode) do
    refute has_element?(view, "#{tool_selector(mode)}[aria-pressed='true']")
  end

  defp open_item_detail(view, item) do
    render_click(element(view, "#section-item-tile-#{item.id}-button"))
    assert_patch(view, ~p"/items/#{item.id}")
  end

  defp assert_water_feedback(view, item_dom_id) do
    assert has_element?(
             view,
             "##{item_dom_id}.garden-care-feedback-water[data-feedback-tone='water']"
           )

    assert_feedback_status(view, item_dom_id, :water)
  end

  defp assert_default_feedback(view, item_dom_id) do
    assert has_element?(
             view,
             "##{item_dom_id}.garden-care-feedback-default[data-feedback-tone='default']"
           )

    assert_feedback_status(view, item_dom_id, :default)
  end

  defp assert_feedback_status(view, base_dom_id, tone) do
    assert has_element?(view, "##{base_dom_id}-feedback.sr-only[data-feedback-tone='#{tone}']")
  end

  defp active_member_and_today do
    household = Households.get_default_household!()
    [member | _rest] = Households.list_members(household)
    {member, Navigation.household_today(household)}
  end

  defp insert_waterings(item, member, dates) do
    Enum.each(dates, fn date ->
      GardenFixtures.care_event_fixture(item, member, %{
        event_type: :watered,
        occurred_on: date
      })
    end)
  end

  defp tool_selector(:browse), do: "#tool-dock-desktop-browse"
  defp tool_selector(:water), do: "#tool-dock-desktop-water"
  defp tool_selector(:soil_check), do: "#tool-dock-desktop-soil-check"
  defp tool_selector(:manual_needs_watering), do: "#tool-dock-desktop-needs-water"
end
