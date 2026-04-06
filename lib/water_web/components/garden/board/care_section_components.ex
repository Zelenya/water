defmodule WaterWeb.Garden.Board.CareSectionComponents do
  use WaterWeb, :html

  alias WaterWeb.Garden.Board.ItemTileComponents
  alias WaterWeb.Garden.Shared.VisualComponents

  attr :item_cards, :list, required: true
  attr :tool_mode, :atom, required: true
  attr :care_feedback, :any, default: nil
  attr :today, :any, required: true
  attr :counts, :map, required: true

  # Answers what needs attention first?
  # Renders due/urgent items, along with summary of near-team workload.
  def care_section(assigns) do
    ~H"""
    <section
      id="today-panel"
      class="garden-panel-soft rounded-[1.8rem] p-4"
    >
      <div class="flex flex-col gap-1.5 sm:flex-row sm:items-end sm:justify-between">
        <h2 class="garden-heading px-4 text-2xl font-semibold tracking-tight">Needs care</h2>
        <div class="flex shrink-0 flex-nowrap gap-1.5">
          <VisualComponents.summary_pill
            id="today-panel-overdue-pill"
            label="Overdue"
            value={@counts.overdue}
            tone="rose"
          />
          <VisualComponents.summary_pill
            id="today-panel-today-pill"
            label="Today"
            value={@counts.today}
            tone="orange"
          />
          <VisualComponents.summary_pill
            id="today-panel-tomorrow-pill"
            label="Tomorrow"
            value={@counts.tomorrow}
            tone="amber"
          />
        </div>
      </div>

      <div id="today-panel-items" class="mt-4 grid gap-3 xl:grid-cols-2">
        <ItemTileComponents.care_item_tile
          :for={item_card <- @item_cards}
          id={"today-panel-item-#{item_card.item.id}"}
          item_card={item_card}
          tool_mode={@tool_mode}
          care_feedback={@care_feedback}
          today={@today}
        />
      </div>
    </section>
    """
  end
end
