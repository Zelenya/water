defmodule WaterWeb.Garden.Board.ItemTileComponents do
  use WaterWeb, :html

  alias Water.Garden.{CareItem, CareItemCard, Schedule}
  alias WaterWeb.Garden.Shared.VisualComponents
  alias WaterWeb.Garden.State.CareFeedback
  alias WaterWeb.Garden.State.ToolMode

  attr :id, :string, required: true
  attr :item_card, :map, required: true
  attr :tool_mode, :atom, required: true
  attr :care_feedback, :any, default: nil
  attr :today, :any, required: true

  def care_item_tile(assigns) do
    ~H"""
    <article
      id={@id}
      data-care-item-id={@item_card.item.id}
      phx-click="interact_with_item"
      phx-value-item-id={@item_card.item.id}
      class={[
        "garden-care-tile rounded-[1.4rem] px-4 py-3.5 transition duration-200",
        actionable_tile_classes(@tool_mode),
        tile_feedback?(@care_feedback, @item_card.item.id) && "garden-care-feedback"
      ]}
    >
      <button
        id={"#{@id}-button"}
        type="button"
        class="group block w-full cursor-pointer text-left focus-visible:outline-none"
        aria-label={tile_action_aria_label(@tool_mode, @item_card)}
      >
        <div class="flex min-w-0 items-center gap-3">
          <span
            id={"#{@id}-type-marker"}
            data-item-icon={VisualComponents.item_icon_name(@item_card.item.type)}
            class="garden-item-type-chip inline-flex size-7 shrink-0 items-center justify-center rounded-xl"
          >
            <VisualComponents.garden_icon
              name={VisualComponents.item_icon_name(@item_card.item.type)}
              class="size-4"
            />
          </span>

          <div class="flex min-w-0 flex-1 items-center justify-between gap-3">
            <div
              id={"#{@id}-title"}
              class="flex min-w-0 flex-1 flex-wrap items-center gap-x-2 gap-y-1"
            >
              <p
                id={"#{@id}-name"}
                class="garden-tile-name garden-text-primary text-[1.05rem] font-semibold tracking-tight"
              >
                {@item_card.item.name}
              </p>
              <VisualComponents.status_badge
                :if={show_tile_status_badge?(@item_card.status)}
                id={"#{@id}-status"}
                status={@item_card.status}
                quiet={true}
              />
            </div>

            <div
              id={"#{@id}-detail"}
              class="garden-tile-detail-row garden-text-faint shrink-0 text-sm"
            >
              {due_text(@item_card)}
            </div>
          </div>
        </div>
      </button>

      <div
        :if={tile_feedback?(@care_feedback, @item_card.item.id)}
        id={"#{@id}-feedback"}
        class="garden-feedback-pill mt-3 inline-flex items-center gap-2 rounded-full px-3 py-1.5 text-xs font-semibold uppercase tracking-[0.18em] motion-safe:animate-pulse"
      >
        <.icon name="hero-check-circle" class="size-4" />
        {feedback_label(@care_feedback)}
      </div>
    </article>
    """
  end

  @spec due_text(CareItemCard.t()) :: String.t()
  defp due_text(%CareItemCard{status: :no_schedule}), do: "No due date"

  defp due_text(%CareItemCard{effective_due_on: %Date{} = due_on}),
    do: "Due #{short_date(due_on)}"

  @spec short_date(Date.t()) :: String.t()
  defp short_date(%Date{} = date), do: Calendar.strftime(date, "%b %-d")

  @spec tile_action_aria_label(ToolMode.t(), CareItemCard.t()) :: String.t()
  defp tile_action_aria_label(:browse, %CareItemCard{item: %CareItem{name: name}}) do
    "Open details for #{name}"
  end

  defp tile_action_aria_label(:water, %CareItemCard{item: %CareItem{name: name}}) do
    "Water #{name}"
  end

  defp tile_action_aria_label(:soil_check, %CareItemCard{item: %CareItem{name: name}}) do
    "Open soil check options for #{name}"
  end

  defp tile_action_aria_label(
         :manual_needs_watering,
         %CareItemCard{item: %CareItem{name: name}}
       ) do
    "Mark #{name} as needing water"
  end

  @spec actionable_tile_classes(ToolMode.t()) :: [String.t()]
  defp actionable_tile_classes(:browse) do
    [
      "garden-care-target-browse",
      "focus-within:ring-2 focus-within:ring-[var(--garden-water-target-ring)]"
    ]
  end

  defp actionable_tile_classes(:water) do
    [
      "garden-care-target garden-care-target-water",
      "focus-within:ring-2 focus-within:ring-[var(--garden-water-highlight-ring)]"
    ]
  end

  defp actionable_tile_classes(:soil_check) do
    [
      "garden-care-target-soil",
      "focus-within:ring-2 focus-within:ring-[var(--garden-water-target-ring)]"
    ]
  end

  defp actionable_tile_classes(:manual_needs_watering) do
    [
      "garden-care-target-manual",
      "focus-within:ring-2 focus-within:ring-[var(--garden-warm-border)]"
    ]
  end

  @spec show_tile_status_badge?(Schedule.status()) :: boolean()
  defp show_tile_status_badge?(:manually_flagged), do: false
  defp show_tile_status_badge?(:normal), do: false
  defp show_tile_status_badge?(:no_schedule), do: false
  defp show_tile_status_badge?(_), do: true

  @spec tile_feedback?(nil | CareFeedback.t(), integer()) :: boolean()
  defp tile_feedback?(nil, _), do: false
  defp tile_feedback?(%CareFeedback{item_id: item_id}, item_id), do: true
  defp tile_feedback?(_, _), do: false

  @spec feedback_label(CareFeedback.t()) :: String.t()
  defp feedback_label(%CareFeedback{label: label}), do: label
end
