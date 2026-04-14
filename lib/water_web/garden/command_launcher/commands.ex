defmodule WaterWeb.Garden.CommandLauncher.Commands do
  @moduledoc false

  alias Water.Garden.Board
  alias Water.Garden.Section
  alias WaterWeb.Garden.CommandLauncher
  alias WaterWeb.Garden.CommandLauncher.Entry
  alias WaterWeb.Garden.CommandLauncher.Ranking
  alias WaterWeb.Garden.State.ToolMode

  # Most important/useful. Show up right away
  @default_entry_ids [
    "command-tool-water",
    "command-tool-soil-check",
    "command-new-item"
  ]

  @spec default_results(CommandLauncher.context()) :: [Entry.t()]
  def default_results(context) do
    context
    |> all_entries()
    |> Enum.filter(&(&1.id in @default_entry_ids))
    |> Enum.sort_by(fn entry -> Enum.find_index(@default_entry_ids, &(&1 == entry.id)) end)
  end

  @spec search_results(CommandLauncher.context(), String.t()) :: [Entry.t()]
  def search_results(context, query) do
    context
    |> all_entries()
    |> Ranking.matching_entries(query, &entry_terms/1, &Ranking.command_sort_key/1)
  end

  @spec all_entries(CommandLauncher.context()) :: [Entry.t()]
  defp all_entries(context) do
    [
      %Entry{
        id: "command-tool-browse",
        title: "Browse",
        subtitle: tool_subtitle(:browse, context.tool_mode),
        group: :commands,
        icon_name: "layout-grid",
        icon_type: :garden,
        keywords: ["browse", "view", "board"],
        action: {:set_tool_mode, :browse},
        selectable?: true,
        current?: context.tool_mode == :browse,
        status: nil
      },
      %Entry{
        id: "command-tool-water",
        title: "Water",
        subtitle: tool_subtitle(:water, context.tool_mode),
        group: :commands,
        icon_name: "droplets",
        icon_type: :garden,
        keywords: ["water", "watering", "drink"],
        action: {:set_tool_mode, :water},
        selectable?: true,
        current?: context.tool_mode == :water,
        status: nil
      },
      %Entry{
        id: "command-tool-soil-check",
        title: "Soil Check",
        subtitle: tool_subtitle(:soil_check, context.tool_mode),
        group: :commands,
        icon_name: "shovel",
        icon_type: :garden,
        keywords: ["soil", "check", "delay"],
        action: {:set_tool_mode, :soil_check},
        selectable?: true,
        current?: context.tool_mode == :soil_check,
        status: nil
      },
      %Entry{
        id: "command-tool-needs-water",
        title: "Needs Water",
        subtitle: tool_subtitle(:manual_needs_watering, context.tool_mode),
        group: :commands,
        icon_name: "flag",
        icon_type: :garden,
        keywords: ["needs", "water", "flag", "tomorrow"],
        action: {:set_tool_mode, :manual_needs_watering},
        selectable?: true,
        current?: context.tool_mode == :manual_needs_watering,
        status: nil
      },
      %Entry{
        id: "command-new-item",
        title: "Add Item",
        subtitle: add_item_subtitle(context.sections),
        group: :commands,
        icon_name: "hero-plus",
        icon_type: :hero,
        keywords: ["add", "item", "new", "create"],
        action: :new_item,
        selectable?: context.sections != [],
        current?: false,
        status: nil
      },
      %Entry{
        id: "command-rain",
        title: "Rain",
        subtitle: "Mark all items as watered today",
        group: :commands,
        icon_name: "cloud-rain",
        icon_type: :garden,
        keywords: ["rain", "water", "all"],
        action: :rain,
        selectable?: context.sections != [],
        current?: false,
        status: nil
      },
      %Entry{
        id: "command-filter-all",
        title: "All",
        subtitle: filter_subtitle(:all, context.current_filter),
        group: :commands,
        icon_name: "hero-squares-2x2",
        icon_type: :hero,
        keywords: ["all", "everything"],
        action: {:set_filter, :all},
        selectable?: true,
        current?: context.current_filter == :all,
        status: nil
      },
      %Entry{
        id: "command-filter-overdue",
        title: "Overdue",
        subtitle: filter_subtitle(:overdue, context.current_filter),
        group: :commands,
        icon_name: "hero-exclamation-triangle",
        icon_type: :hero,
        keywords: ["overdue", "late"],
        action: {:set_filter, :overdue},
        selectable?: true,
        current?: context.current_filter == :overdue,
        status: nil
      },
      %Entry{
        id: "command-filter-today",
        title: "Today",
        subtitle: filter_subtitle(:today, context.current_filter),
        group: :commands,
        icon_name: "hero-sun",
        icon_type: :hero,
        keywords: ["today", "now"],
        action: {:set_filter, :today},
        selectable?: true,
        current?: context.current_filter == :today,
        status: nil
      },
      %Entry{
        id: "command-filter-soon",
        title: "Soon",
        subtitle: filter_subtitle(:tomorrow, context.current_filter),
        group: :commands,
        icon_name: "hero-calendar-days",
        icon_type: :hero,
        keywords: ["soon", "tomorrow"],
        action: {:set_filter, :tomorrow},
        selectable?: true,
        current?: context.current_filter == :tomorrow,
        status: nil
      },
      %Entry{
        id: "command-filter-no-schedule",
        title: "No schedule",
        subtitle: filter_subtitle(:no_schedule, context.current_filter),
        group: :commands,
        icon_name: "hero-minus-circle",
        icon_type: :hero,
        keywords: ["no schedule", "unscheduled", "none"],
        action: {:set_filter, :no_schedule},
        selectable?: true,
        current?: context.current_filter == :no_schedule,
        status: nil
      }
    ]
  end

  @spec entry_terms(Entry.t()) :: [String.t()]
  defp entry_terms(%Entry{} = entry), do: [entry.title | entry.keywords]

  @spec tool_subtitle(ToolMode.t(), ToolMode.t()) :: String.t()
  defp tool_subtitle(mode, mode), do: "Current tool"
  defp tool_subtitle(:browse, _current_mode), do: "Return to board browsing"
  defp tool_subtitle(:water, _current_mode), do: "Click items to water them"
  defp tool_subtitle(:soil_check, _current_mode), do: "Check and postpone watering"
  defp tool_subtitle(:manual_needs_watering, _current_mode), do: "Flag items that need water"

  @spec filter_subtitle(Board.filter(), Board.filter()) :: String.t()
  defp filter_subtitle(filter, filter), do: "Current filter"
  defp filter_subtitle(:all, _current_filter), do: "Show every item on the board"
  defp filter_subtitle(:overdue, _current_filter), do: "Show overdue items"
  defp filter_subtitle(:today, _current_filter), do: "Show items due today"
  defp filter_subtitle(:tomorrow, _current_filter), do: "Show items due soon"
  defp filter_subtitle(:no_schedule, _current_filter), do: "Show items without a schedule"

  @spec add_item_subtitle([Section.t()]) :: String.t()
  defp add_item_subtitle([]), do: "Add a section first to create items"
  defp add_item_subtitle(_sections), do: "Create a new care card"
end
