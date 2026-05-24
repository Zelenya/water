defmodule WaterWeb.GardenBoardLiveTest do
  use WaterWeb.ConnCase, async: true

  import Ecto.Query
  import Phoenix.LiveViewTest
  import WaterWeb.GardenLiveTestHelpers

  alias Water.Garden.{CareEvent, CareItem, Section}
  alias Water.GardenFixtures
  alias Water.Repo
  alias WaterWeb.GardenLive.Navigation

  describe "board shell" do
    test "renders the board with the active member, tools, needs care items, and section tiles",
         %{
           conn: conn
         } do
      household = GardenFixtures.default_household_fixture()
      _member = GardenFixtures.member_fixture(household, %{name: "A"})
      section = GardenFixtures.section_fixture(household, %{name: "Front", position: 0})
      today = Navigation.household_today(household)

      item =
        GardenFixtures.care_item_fixture(section, %{
          name: "Blueberry bed west edge",
          type: :bed,
          next_due_on: today,
          position: 0
        })

      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "#garden-shell")
      assert has_element?(view, "#garden-daily-reminder")

      assert has_element?(
               view,
               "#garden-daily-reminder[data-daily-reminder-date='#{Date.to_iso8601(today)}'][data-daily-reminder-body='1 item due today.']"
             )

      assert has_element?(view, "#garden-top-hud")
      assert has_element?(view, "#garden-weather-cards.grid-cols-3")
      assert has_element?(view, "#garden-weather-hook")
      assert has_element?(view, "#garden-weather-card-today", "--°C/--°C")
      assert has_element?(view, "#garden-weather-card-tomorrow", "--°C/--°C")
      assert has_element?(view, "#garden-weather-card-rain", "Checking rain")
      assert has_element?(view, "#header-active-member", "Active member: A")
      assert has_element?(view, "#theme-toggle")
      assert has_element?(view, "#theme-toggle-system")
      assert has_element?(view, "#theme-toggle-light")
      assert has_element?(view, "#theme-toggle-dark")
      assert has_element?(view, "#tool-dock-desktop")
      assert has_element?(view, "#tool-dock-desktop-water [data-lucide-icon='droplets']")
      assert has_element?(view, "#tool-dock-desktop-needs-water [data-lucide-icon='flag']")
      assert has_element?(view, "#tool-dock-mobile")
      assert has_element?(view, "#tool-dock-mobile-browse[aria-label='Browse']")
      assert has_element?(view, "#tool-dock-mobile-water [data-lucide-icon='droplets']")
      assert has_element?(view, "#tool-dock-mobile-add-item[aria-label='Add Item']")
      refute has_element?(view, "#tool-dock-mobile .garden-tool-label")
      assert has_element?(view, "#garden-board-controls")
      assert has_element?(view, "#garden-board-toolbar")
      assert has_element?(view, "#garden-board-filters")
      assert has_element?(view, "#today-panel")
      assert has_element?(view, "#garden-section-#{section.id}")
      assert has_element?(view, "#garden-section-#{section.id}-actions")
      assert has_element?(view, "#garden-section-#{section.id}-summary")

      assert has_element?(
               view,
               "#garden-section-#{section.id}-overdue.garden-summary-pill-compact"
             )

      assert has_element?(view, "#garden-section-#{section.id}-today.garden-summary-pill-compact")

      assert has_element?(
               view,
               "#garden-section-#{section.id}-tomorrow.garden-summary-pill-compact"
             )

      assert has_element?(view, "#garden-section-#{section.id}-add-item", "Add care item")
      assert has_element?(view, "#garden-section-#{section.id}-rename", "Rename")
      assert has_element?(view, "#garden-section-#{section.id}-delete", "Delete")
      assert has_element?(view, "#section-item-tile-#{item.id}")

      assert has_element?(
               view,
               "#garden-section-items-#{section.id}[data-tile-layout='list'][data-sortable-enabled='true']"
             )

      assert has_element?(view, "#section-item-tile-#{item.id}-drag-handle")
      assert has_element?(view, "#section-item-tile-#{item.id}-button")
      refute has_element?(view, "#today-panel-item-#{item.id}-drag-handle")
      assert has_element?(view, "#today-panel-item-#{item.id}-name", item.name)
      assert has_element?(view, "#today-panel-overdue-pill", "Overdue 0")
      assert has_element?(view, "#today-panel-today-pill", "Today 1")
      assert has_element?(view, "#today-panel-tomorrow-pill", "Tomorrow 0")
      assert has_element?(view, "#section-item-tile-#{item.id}-name", item.name)
      assert has_element?(view, "#section-item-tile-#{item.id}-title", item.name)

      assert has_element?(
               view,
               "#section-item-tile-#{item.id}-title #section-item-tile-#{item.id}-status"
             )

      assert has_element?(
               view,
               "#section-item-tile-#{item.id}-type-marker[data-item-icon='bed-single']"
             )

      assert has_element?(
               view,
               "#section-item-tile-#{item.id}-detail",
               "Due #{Calendar.strftime(today, "%b %-d")}"
             )

      refute has_element?(view, "#active-member-status")
      refute has_element?(view, "#garden-section-#{section.id} .garden-kicker", "Section")
      refute has_element?(view, "#garden-section-count")
      refute has_element?(view, "#garden-item-count")
      refute has_element?(view, "#garden-top-hud", household.name)
      refute has_element?(view, "#section-item-tile-#{item.id}-type")
      refute has_element?(view, "#section-item-tile-#{item.id}-detail", "Due today")
      refute has_element?(view, "#section-item-tile-#{item.id}", "Open")
      refute has_element?(view, "#section-item-tile-#{item.id}", "Water now")
      refute has_element?(view, "#section-item-tile-#{item.id}", "Soil check")
      refute has_element?(view, "#section-item-tile-#{item.id}", "Mark")
    end

    test "supports alternate authenticated members" do
      household = GardenFixtures.default_household_fixture()
      _member = GardenFixtures.member_fixture(household, %{name: "J"})

      conn = authenticated_conn(build_conn(), "j")

      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "#header-active-member", "Active member: J")
    end
  end

  describe "section actions" do
    test "opens add item modal with the current section preselected", %{conn: conn} do
      household = GardenFixtures.default_household_fixture()
      _member = GardenFixtures.member_fixture(household, %{name: "A"})
      front = GardenFixtures.section_fixture(household, %{name: "Front", position: 0})
      back = GardenFixtures.section_fixture(household, %{name: "Back", position: 1})

      {:ok, view, _html} = live(conn, ~p"/")

      render_click(element(view, "#garden-section-#{back.id}-add-item"))
      assert_patch(view, ~p"/items/new?#{%{"section_id" => back.id}}")

      assert has_element?(view, "#garden-item-form")

      assert has_element?(
               view,
               "#garden-item-form select[name='item[section_id]'] option[value='#{back.id}'][selected]"
             )

      view
      |> form("#garden-item-form",
        item: %{
          name: "Back Basil",
          type: "plant",
          watering_interval_days: "3"
        }
      )
      |> render_submit()

      assert_patch(view, ~p"/")
      assert has_element?(view, "#garden-section-items-#{back.id}", "Back Basil")
      refute has_element?(view, "#garden-section-items-#{front.id}", "Back Basil")
    end

    test "renames a section inline from the actions menu", %{conn: conn} do
      household = GardenFixtures.default_household_fixture()
      _member = GardenFixtures.member_fixture(household, %{name: "A"})
      section = GardenFixtures.section_fixture(household, %{name: "Front", position: 0})

      {:ok, view, _html} = live(conn, ~p"/")

      render_click(element(view, "#garden-section-#{section.id}-rename"))

      assert has_element?(view, "#garden-section-#{section.id}-rename-form")

      view
      |> form("#garden-section-#{section.id}-rename-form", section: %{name: "Kitchen"})
      |> render_submit()

      assert has_element?(view, "#garden-section-#{section.id}-title", "Kitchen")
      refute has_element?(view, "#garden-section-#{section.id}-rename-form")
      assert Repo.get!(Section, section.id).name == "Kitchen"
    end

    test "keeps inline rename open when the submitted name is invalid", %{conn: conn} do
      household = GardenFixtures.default_household_fixture()
      _member = GardenFixtures.member_fixture(household, %{name: "A"})
      section = GardenFixtures.section_fixture(household, %{name: "Front", position: 0})

      {:ok, view, _html} = live(conn, ~p"/")

      render_click(element(view, "#garden-section-#{section.id}-rename"))

      view
      |> form("#garden-section-#{section.id}-rename-form", section: %{name: ""})
      |> render_submit()

      assert has_element?(view, "#garden-section-#{section.id}-rename-form")
      assert has_element?(view, "#garden-section-#{section.id}-rename-form input.input-error")
      assert Repo.get!(Section, section.id).name == "Front"
    end

    test "escape cancels inline section rename without changing the title", %{conn: conn} do
      household = GardenFixtures.default_household_fixture()
      _member = GardenFixtures.member_fixture(household, %{name: "A"})
      section = GardenFixtures.section_fixture(household, %{name: "Front", position: 0})

      {:ok, view, _html} = live(conn, ~p"/")

      render_click(element(view, "#garden-section-#{section.id}-rename"))
      assert has_element?(view, "#garden-section-#{section.id}-rename-form")

      render_keydown(view, "escape_tool_mode", %{"key" => "Escape"})

      refute has_element?(view, "#garden-section-#{section.id}-rename-form")
      assert has_element?(view, "#garden-section-#{section.id}-title", "Front")
      assert Repo.get!(Section, section.id).name == "Front"
    end

    test "deletes a section and all of its contents from the actions menu", %{conn: conn} do
      household = GardenFixtures.default_household_fixture()
      member = GardenFixtures.member_fixture(household, %{name: "A"})
      section = GardenFixtures.section_fixture(household, %{name: "Front", position: 0})
      item = GardenFixtures.care_item_fixture(section, %{name: "Mint", position: 0})
      event = GardenFixtures.care_event_fixture(item, member)

      {:ok, view, _html} = live(conn, ~p"/")

      render_click(element(view, "#garden-section-#{section.id}-delete"))

      refute has_element?(view, "#garden-section-#{section.id}")
      assert has_element?(view, "#garden-board-empty")
      assert Repo.get(Section, section.id) == nil
      assert Repo.get(CareItem, item.id) == nil
      assert Repo.get(CareEvent, event.id) == nil
    end
  end

  describe "tool modes" do
    test "switches tools and keeps the active mode through filter and modal patches", %{
      conn: conn
    } do
      _board = seed_board()

      {:ok, view, _html} = live(conn, ~p"/")

      render_click(element(view, "#tool-dock-desktop-soil-check"))
      assert has_element?(view, "#tool-dock-desktop-soil-check[aria-pressed='true']")

      render_click(element(view, "#filter-chip-today"))
      assert_patch(view, ~p"/?filter=today")
      assert has_element?(view, "#tool-dock-desktop-soil-check[aria-pressed='true']")

      render_click(element(view, "#tool-dock-desktop-add-item"))
      assert_patch(view, ~p"/items/new?#{%{"filter" => "today"}}")
      assert has_element?(view, "#tool-dock-desktop-soil-check[aria-pressed='true']")

      render_click(element(view, "#garden-modal-close"))
      assert_patch(view, ~p"/?filter=today")
      assert has_element?(view, "#tool-dock-desktop-soil-check[aria-pressed='true']")
    end
  end

  describe "filters" do
    test "shows the filter empty state when a filter has no matching items", %{conn: conn} do
      household = GardenFixtures.default_household_fixture()
      _member = GardenFixtures.member_fixture(household, %{name: "A"})
      section = GardenFixtures.section_fixture(household, %{name: "Back", position: 0})
      today = Navigation.household_today(household)

      _later_item =
        GardenFixtures.care_item_fixture(section, %{
          name: "Later",
          next_due_on: Date.add(today, 4),
          position: 0
        })

      {:ok, view, _html} = live(conn, ~p"/?filter=overdue")

      assert has_element?(view, "#garden-filter-empty")
      assert has_element?(view, "#garden-filter-empty", "Nothing matches this filter")

      assert has_element?(
               view,
               "#garden-filter-empty",
               "Great news: nothing is overdue!"
             )

      refute has_element?(view, "#garden-board")
    end

    test "watering in the today filter removes the acted-on item from the filtered board", %{
      conn: conn
    } do
      %{today_item: today_item} = seed_board()

      {:ok, view, _html} = live(conn, ~p"/?filter=today")

      render_click(element(view, "#tool-dock-desktop-water"))
      render_click(element(view, "#section-item-tile-#{today_item.id}-button"))

      refute has_element?(view, "#section-item-tile-#{today_item.id}")
    end

    test "tomorrow filter shows both natural and manually-marked tomorrow items as soon", %{
      conn: conn
    } do
      household = GardenFixtures.default_household_fixture()
      _member = GardenFixtures.member_fixture(household, %{name: "A"})
      section = GardenFixtures.section_fixture(household, %{name: "Back", position: 0})
      today = Navigation.household_today(household)
      tomorrow = Date.add(today, 1)

      natural_tomorrow_item =
        GardenFixtures.care_item_fixture(section, %{
          name: "Natural Tomorrow",
          next_due_on: tomorrow,
          position: 0
        })

      manual_tomorrow_item =
        GardenFixtures.care_item_fixture(section, %{
          name: "Manual Tomorrow",
          next_due_on: Date.add(today, 5),
          manual_due_on: tomorrow,
          position: 1
        })

      {:ok, view, _html} = live(conn, ~p"/?filter=tomorrow")

      assert has_element?(view, "#section-item-tile-#{natural_tomorrow_item.id}-status", "Soon")
      assert has_element?(view, "#section-item-tile-#{manual_tomorrow_item.id}-status", "Soon")
      refute has_element?(view, "#section-item-tile-#{manual_tomorrow_item.id}-status", "Flagged")
    end

    test "no-schedule filter shows only no-schedule items", %{conn: conn} do
      %{no_schedule_item: no_schedule_item, tomorrow_item: tomorrow_item} = seed_board()

      {:ok, view, _html} = live(conn, ~p"/?filter=no_schedule")

      assert has_element?(view, "#filter-chip-no-schedule.garden-filter-chip-selected")
      assert has_element?(view, "#section-item-tile-#{no_schedule_item.id}")
      assert has_element?(view, "#section-item-tile-#{no_schedule_item.id}-detail", "No due date")
      refute has_element?(view, "#section-item-tile-#{tomorrow_item.id}")
    end
  end

  describe "section empty states" do
    test "shows the inline section empty state when a section has no items", %{conn: conn} do
      household = GardenFixtures.default_household_fixture()
      _member = GardenFixtures.member_fixture(household, %{name: "A"})
      empty_section = GardenFixtures.section_fixture(household, %{name: "Empty", position: 0})

      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "#garden-section-#{empty_section.id}")

      assert has_element?(
               view,
               "#garden-section-empty-#{empty_section.id}",
               "This section is ready for items, but nothing has been added yet."
             )
    end
  end

  describe "drag sorting" do
    test "disables sortable handles outside the all filter", %{conn: conn} do
      household = GardenFixtures.default_household_fixture()
      _member = GardenFixtures.member_fixture(household, %{name: "A"})
      section = GardenFixtures.section_fixture(household, %{name: "Front", position: 0})
      today = Navigation.household_today(household)

      item =
        GardenFixtures.care_item_fixture(section, %{
          name: "Today",
          next_due_on: today,
          position: 0
        })

      {:ok, view, _html} = live(conn, ~p"/?filter=today")

      assert has_element?(
               view,
               "#garden-section-items-#{section.id}[data-sortable-enabled='false']"
             )

      refute has_element?(view, "#section-item-tile-#{item.id}-drag-handle")
    end

    test "moves an item between sections from the sortable hook", %{conn: conn} do
      household = GardenFixtures.default_household_fixture()
      _member = GardenFixtures.member_fixture(household, %{name: "A"})
      source = GardenFixtures.section_fixture(household, %{name: "Front", position: 0})
      destination = GardenFixtures.section_fixture(household, %{name: "Back", position: 1})

      source_item = GardenFixtures.care_item_fixture(source, %{name: "Mint", position: 0})
      moved_item = GardenFixtures.care_item_fixture(source, %{name: "Basil", position: 1})

      destination_item =
        GardenFixtures.care_item_fixture(destination, %{name: "Sage", position: 0})

      {:ok, view, _html} = live(conn, ~p"/")

      render_hook(view, "reposition_care_item", %{
        "item_id" => to_string(moved_item.id),
        "sections" => [
          %{
            "section_id" => to_string(source.id),
            "item_ids" => [to_string(source_item.id)]
          },
          %{
            "section_id" => to_string(destination.id),
            "item_ids" => [to_string(destination_item.id), to_string(moved_item.id)]
          }
        ]
      })

      assert has_element?(view, "#garden-section-items-#{destination.id}", "Basil")
      refute has_element?(view, "#garden-section-items-#{source.id}", "Basil")

      assert item_order(source) == [{source_item.id, "Mint", 0}]

      assert item_order(destination) == [
               {destination_item.id, "Sage", 0},
               {moved_item.id, "Basil", 1}
             ]
    end

    test "reorders items within a section from the sortable hook", %{conn: conn} do
      household = GardenFixtures.default_household_fixture()
      _member = GardenFixtures.member_fixture(household, %{name: "A"})
      section = GardenFixtures.section_fixture(household, %{name: "Front", position: 0})

      first = GardenFixtures.care_item_fixture(section, %{name: "First", position: 0})
      second = GardenFixtures.care_item_fixture(section, %{name: "Second", position: 1})
      third = GardenFixtures.care_item_fixture(section, %{name: "Third", position: 2})

      {:ok, view, _html} = live(conn, ~p"/")

      render_hook(view, "reposition_care_item", %{
        "item_id" => to_string(third.id),
        "sections" => [
          %{
            "section_id" => to_string(section.id),
            "item_ids" => [to_string(third.id), to_string(first.id), to_string(second.id)]
          }
        ]
      })

      assert has_element?(view, "#garden-section-items-#{section.id}", "Third")

      assert item_order(section) == [
               {third.id, "Third", 0},
               {first.id, "First", 1},
               {second.id, "Second", 2}
             ]
    end
  end

  describe "tile status copy" do
    test "main board hides flagged, normal, and no-schedule badges and uses no due date copy",
         %{
           conn: conn
         } do
      household = GardenFixtures.default_household_fixture()
      _member = GardenFixtures.member_fixture(household, %{name: "A"})
      section = GardenFixtures.section_fixture(household, %{name: "Back", position: 0})
      today = Navigation.household_today(household)

      flagged_item =
        GardenFixtures.care_item_fixture(section, %{
          name: "Flagged",
          next_due_on: Date.add(today, 5),
          manual_due_on: Date.add(today, 2),
          position: 0
        })

      normal_item =
        GardenFixtures.care_item_fixture(section, %{
          name: "Normal",
          next_due_on: Date.add(today, 6),
          position: 1
        })

      no_schedule_item =
        GardenFixtures.care_item_fixture(section, %{
          name: "No Schedule",
          watering_interval_days: nil,
          next_due_on: nil,
          position: 2
        })

      {:ok, view, _html} = live(conn, ~p"/")

      refute has_element?(view, "#section-item-tile-#{flagged_item.id}-status")
      refute has_element?(view, "#section-item-tile-#{normal_item.id}-status")
      refute has_element?(view, "#section-item-tile-#{no_schedule_item.id}-status")

      assert has_element?(
               view,
               "#section-item-tile-#{flagged_item.id}-detail",
               "Due #{Calendar.strftime(flagged_item.manual_due_on, "%b %-d")}"
             )

      refute has_element?(
               view,
               "#section-item-tile-#{flagged_item.id}-detail",
               "Marked for"
             )

      assert has_element?(view, "#section-item-tile-#{no_schedule_item.id}-detail", "No due date")
    end
  end

  @spec item_order(Section.t()) :: [{CareItem.id(), String.t(), non_neg_integer()}]
  defp item_order(%Section{id: section_id}) do
    from(care_item in CareItem,
      where: care_item.section_id == ^section_id,
      order_by: [asc: care_item.position, asc: care_item.inserted_at],
      select: {care_item.id, care_item.name, care_item.position}
    )
    |> Repo.all()
  end
end
