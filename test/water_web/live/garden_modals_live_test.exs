defmodule WaterWeb.GardenModalsLiveTest do
  use WaterWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import WaterWeb.GardenLiveTestHelpers

  alias Water.GardenFixtures

  describe "detail routing" do
    test "clicking a tile in browse mode opens the detail modal and closing it preserves the filter",
         %{
           conn: conn
         } do
      %{overdue_item: overdue_item} = seed_board()

      {:ok, view, _html} = live(conn, ~p"/?filter=overdue")

      render_click(element(view, "#section-item-tile-#{overdue_item.id}"))
      assert_patch(view, ~p"/items/#{overdue_item.id}?#{%{"filter" => "overdue"}}")

      assert has_element?(view, "#item-detail-modal")
      assert has_element?(view, "#item-detail-modal", overdue_item.name)

      render_click(element(view, "#garden-modal-close"))
      assert_patch(view, ~p"/?filter=overdue")

      refute has_element?(view, "#item-detail-modal")
      assert has_element?(view, "#garden-board-toolbar #filter-chip-overdue")
    end

    test "escape closes the detail modal and preserves the current filter", %{conn: conn} do
      %{overdue_item: overdue_item} = seed_board()

      {:ok, view, _html} = live(conn, ~p"/?filter=overdue")

      render_click(element(view, "#section-item-tile-#{overdue_item.id}"))
      assert_patch(view, ~p"/items/#{overdue_item.id}?#{%{"filter" => "overdue"}}")
      assert has_element?(view, "#item-detail-modal")

      render_keydown(view, "escape_tool_mode", %{"key" => "Escape"})

      assert_patch(view, ~p"/?filter=overdue")
      refute has_element?(view, "#item-detail-modal")
      assert has_element?(view, "#garden-board-toolbar #filter-chip-overdue")
    end

    test "detail modal renders recent history with actor names and labels", %{conn: conn} do
      household = GardenFixtures.default_household_fixture()
      actor_a = GardenFixtures.member_fixture(household, %{name: "A"})
      actor_j = GardenFixtures.member_fixture(household, %{name: "J"})
      section = GardenFixtures.section_fixture(household, %{name: "Front", position: 0})
      item = GardenFixtures.care_item_fixture(section, %{name: "History Mint", position: 0})

      _watered =
        GardenFixtures.care_event_fixture(item, actor_a, %{
          event_type: :watered,
          occurred_on: household_today(household),
          previous_due_on: household_today(household),
          resulting_due_on: Date.add(household_today(household), 3)
        })

      marked =
        GardenFixtures.care_event_fixture(item, actor_j, %{
          event_type: :manual_needs_watering,
          occurred_on: Date.add(household_today(household), -1),
          manual_target_on: household_today(household),
          previous_due_on: Date.add(household_today(household), 2),
          resulting_due_on: household_today(household)
        })

      {:ok, view, _html} = live(conn, ~p"/")

      render_click(element(view, "#section-item-tile-#{item.id}"))
      assert_patch(view, ~p"/items/#{item.id}")

      assert has_element?(view, "#item-detail-history")
      assert has_element?(view, "#item-detail-history", "Watered")
      assert has_element?(view, "#item-detail-history", "Marked needs water")
      assert has_element?(view, "#item-detail-history", "A")
      assert has_element?(view, "#item-detail-history", "J")
      assert has_element?(view, "#item-detail-history-event-#{marked.id} .flex-col")
      assert has_element?(view, "#item-detail-due")
      assert has_element?(view, "#item-detail-interval", "Every 3 days")
      assert has_element?(view, "#item-detail-last-watered")
      assert has_element?(view, "#item-detail-last-checked")
      refute has_element?(view, "#item-detail-next-due")
      refute has_element?(view, "#item-detail-last-care-event")
    end

    test "detail modal shows the empty history state when an item has no care events", %{
      conn: conn
    } do
      household = GardenFixtures.default_household_fixture()
      _member = GardenFixtures.member_fixture(household, %{name: "A"})
      section = GardenFixtures.section_fixture(household, %{name: "Front", position: 0})
      item = GardenFixtures.care_item_fixture(section, %{name: "Quiet Mint", position: 0})

      {:ok, view, _html} = live(conn, ~p"/")

      render_click(element(view, "#section-item-tile-#{item.id}"))
      assert_patch(view, ~p"/items/#{item.id}")

      assert has_element?(view, "#item-detail-history")
      assert has_element?(view, "#item-detail-history-empty")
      refute has_element?(view, "#item-detail-history [id^='item-detail-history-event-']")
    end

    test "the detail modal can still patch into the edit modal", %{conn: conn} do
      household = GardenFixtures.default_household_fixture()
      _member = GardenFixtures.member_fixture(household, %{name: "A"})
      section = GardenFixtures.section_fixture(household, %{name: "Front", position: 0})
      item = GardenFixtures.care_item_fixture(section, %{name: "Edit Me", position: 0})

      {:ok, view, _html} = live(conn, ~p"/")

      render_click(element(view, "#section-item-tile-#{item.id}"))
      assert_patch(view, ~p"/items/#{item.id}")

      render_click(element(view, "#item-detail-edit"))
      assert_patch(view, ~p"/items/#{item.id}/edit")

      assert has_element?(view, "#item-form-modal")
      assert has_element?(view, "#garden-item-form")
    end
  end

  describe "item forms" do
    test "new item validates required fields and section selection", %{conn: conn} do
      household = GardenFixtures.default_household_fixture()
      _member = GardenFixtures.member_fixture(household, %{name: "A"})
      _section = GardenFixtures.section_fixture(household, %{name: "Front", position: 0})

      {:ok, view, _html} = live(conn, ~p"/")

      render_click(element(view, "#tool-dock-desktop-add-item"))
      assert_patch(view, ~p"/items/new")
      assert has_element?(view, "#garden-item-form")

      view
      |> form("#garden-item-form",
        item: %{
          name: "",
          type: "",
          section_id: "",
          watering_interval_days: ""
        }
      )
      |> render_submit()

      assert has_element?(view, "#garden-item-form p", "can't be blank")
    end

    test "editing an item updates the visible board state after save", %{conn: conn} do
      household = GardenFixtures.default_household_fixture()
      _member = GardenFixtures.member_fixture(household, %{name: "A"})
      section = GardenFixtures.section_fixture(household, %{name: "Front", position: 0})
      item = GardenFixtures.care_item_fixture(section, %{name: "Mint", position: 0})

      {:ok, view, _html} = live(conn, ~p"/")

      render_click(element(view, "#section-item-tile-#{item.id}"))
      assert_patch(view, ~p"/items/#{item.id}")
      render_click(element(view, "#item-detail-edit"))
      assert_patch(view, ~p"/items/#{item.id}/edit")

      view
      |> form("#garden-item-form",
        item: %{
          name: "Chocolate Mint",
          type: "plant",
          section_id: Integer.to_string(section.id),
          watering_interval_days: Integer.to_string(item.watering_interval_days)
        }
      )
      |> render_submit()

      assert_patch(view, ~p"/")
      assert has_element?(view, "#section-item-tile-#{item.id}", "Chocolate Mint")
    end

    test "editing a no-schedule item can switch it back to recurring", %{conn: conn} do
      household = GardenFixtures.default_household_fixture()
      _member = GardenFixtures.member_fixture(household, %{name: "A"})
      section = GardenFixtures.section_fixture(household, %{name: "Front", position: 0})
      today = household_today(household)

      item =
        GardenFixtures.care_item_fixture(section, %{
          name: "Unsheduled Mint",
          watering_interval_days: nil,
          next_due_on: nil,
          position: 0
        })

      {:ok, view, _html} = live(conn, ~p"/")

      render_click(element(view, "#section-item-tile-#{item.id}"))
      render_click(element(view, "#item-detail-edit"))
      assert_patch(view, ~p"/items/#{item.id}/edit")

      refute has_element?(view, "#garden-item-form input[name='item[watering_interval_days]']")

      render_change(element(view, "#garden-item-form"), %{
        "item" => %{
          "name" => item.name,
          "type" => "plant",
          "section_id" => Integer.to_string(section.id),
          "schedule_mode" => "recurring"
        }
      })

      assert has_element?(view, "#garden-item-form input[name='item[watering_interval_days]']")

      view
      |> form("#garden-item-form",
        item: %{
          name: item.name,
          type: "plant",
          section_id: Integer.to_string(section.id),
          schedule_mode: "recurring",
          watering_interval_days: "4"
        }
      )
      |> render_submit()

      refute has_element?(view, "#item-form-modal")

      assert has_element?(
               view,
               "#section-item-tile-#{item.id}-detail",
               "Due #{Calendar.strftime(Date.add(today, 4), "%b %-d")}"
             )
    end

    test "editing an item silently ignores schedule-only saves that keep the same due date",
         %{conn: conn} do
      household = GardenFixtures.default_household_fixture()
      _member = GardenFixtures.member_fixture(household, %{name: "A"})
      section = GardenFixtures.section_fixture(household, %{name: "Front", position: 0})

      item =
        GardenFixtures.care_item_fixture(section, %{
          name: "Mint",
          watering_interval_days: 3,
          next_due_on: ~D[2026-04-05],
          manual_due_on: ~D[2026-04-02],
          position: 0
        })

      {:ok, view, _html} = live(conn, ~p"/")

      render_click(element(view, "#section-item-tile-#{item.id}"))
      render_click(element(view, "#item-detail-edit"))
      assert_patch(view, ~p"/items/#{item.id}/edit")

      view
      |> form("#garden-item-form",
        item: %{
          name: item.name,
          type: "plant",
          section_id: Integer.to_string(section.id),
          schedule_mode: "recurring",
          watering_interval_days: "5"
        }
      )
      |> render_submit()

      refute has_element?(view, "#item-form-modal")
      assert has_element?(view, "#section-item-tile-#{item.id}-detail", "Due Apr 2")
    end

    test "add item stays disabled and the empty state explains why when there are no sections", %{
      conn: conn
    } do
      household = GardenFixtures.default_household_fixture()
      _member = GardenFixtures.member_fixture(household, %{name: "A"})

      {:ok, view, _html} = live(conn, ~p"/")

      assert household.slug == "default"
      assert has_element?(view, "#garden-board-empty")
      assert has_element?(view, "#tool-dock-desktop-add-item[disabled]")
      assert has_element?(view, "#tool-dock-mobile-add-item[disabled]")
    end

    test "the new item route shows the unavailable modal when no sections exist", %{conn: conn} do
      household = GardenFixtures.default_household_fixture()
      _member = GardenFixtures.member_fixture(household, %{name: "A"})

      {:ok, view, _html} = live(conn, ~p"/items/new")

      assert household.slug == "default"
      assert has_element?(view, "#item-form-unavailable-modal")

      assert has_element?(
               view,
               "#item-form-unavailable-modal",
               "Add Item is disabled until the household has at least one section."
             )

      assert has_element?(view, "#garden-board-empty")
    end
  end
end
