defmodule WaterWeb.Garden.CommandLauncher.Items do
  @moduledoc false

  alias Water.Garden
  alias Water.Garden.{CareItemCard, Section}
  alias WaterWeb.Garden.CommandLauncher
  alias WaterWeb.Garden.CommandLauncher.Entry
  alias WaterWeb.Garden.CommandLauncher.Ranking
  alias WaterWeb.Garden.Shared.VisualComponents

  @spec search_results(CommandLauncher.context(), String.t()) :: [Entry.t()]
  def search_results(context, query) do
    context
    |> all_entries()
    |> Ranking.matching_entries(query, &entry_terms/1, &Ranking.item_sort_key/1)
  end

  @spec all_entries(CommandLauncher.context()) :: [Entry.t()]
  defp all_entries(context) do
    context.household
    |> Garden.list_household_items()
    |> Enum.map(fn item ->
      item_card = CareItemCard.from_item(item, context.today)
      current_section_name = section_name(context.section_lookup, item.section_id)

      %Entry{
        id: "item-#{item.id}",
        title: item.name,
        subtitle: item_subtitle(current_section_name, item_card),
        group: :items,
        icon_name: VisualComponents.item_icon_name(item.type),
        icon_type: :garden,
        keywords: [item.name, current_section_name],
        action: {:show_item, item.id},
        selectable?: true,
        current?: false,
        status: item_card.status
      }
    end)
  end

  @spec entry_terms(Entry.t()) :: [String.t()]
  defp entry_terms(%Entry{} = entry), do: [entry.title | entry.keywords]

  @spec item_subtitle(String.t(), CareItemCard.t()) :: String.t()
  defp item_subtitle(section_name, %CareItemCard{} = item_card) do
    section_name <> " · " <> due_copy(item_card)
  end

  @spec due_copy(CareItemCard.t()) :: String.t()
  defp due_copy(%CareItemCard{status: :due_today}), do: "Due today"
  defp due_copy(%CareItemCard{status: :overdue}), do: "Overdue"
  defp due_copy(%CareItemCard{status: :soon}), do: "Due tomorrow"

  defp due_copy(%CareItemCard{status: :manually_flagged, effective_due_on: %Date{} = due_on}) do
    "Flagged for #{Calendar.strftime(due_on, "%b %-d")}"
  end

  defp due_copy(%CareItemCard{status: :normal, effective_due_on: %Date{} = due_on}) do
    "Due #{Calendar.strftime(due_on, "%b %-d")}"
  end

  defp due_copy(%CareItemCard{status: :no_schedule}), do: "No schedule"

  @spec section_name(%{optional(Section.id()) => Section.t()}, Section.id() | nil) :: String.t()
  defp section_name(section_lookup, section_id) do
    case Map.get(section_lookup, section_id) do
      %Section{name: name} -> name
      nil -> "Unknown section"
    end
  end
end
