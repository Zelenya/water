defmodule WaterWeb.Garden.Board.SectionComponents do
  use WaterWeb, :html

  alias WaterWeb.Garden.Board.ItemTileComponents
  alias WaterWeb.Garden.Shared.VisualComponents

  attr :section_card, :map, required: true
  attr :tool_mode, :atom, required: true
  attr :care_feedback, :any, default: nil
  attr :today, :any, required: true

  def garden_section(assigns) do
    ~H"""
    <article
      id={"garden-section-#{@section_card.section.id}"}
      class="garden-panel-card rounded-[1.8rem] p-5"
    >
      <div class="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
        <div class="min-w-0 flex-1">
          <h3 class="garden-heading px-4 text-xl font-semibold tracking-tight">
            {@section_card.section.name}
          </h3>
        </div>

        <div class="flex shrink-0 flex-nowrap gap-1.5">
          <VisualComponents.summary_pill
            id={"garden-section-#{@section_card.section.id}-overdue"}
            label="Overdue"
            value={@section_card.summary.overdue}
            tone="rose"
          />

          <VisualComponents.summary_pill
            id={"garden-section-#{@section_card.section.id}-today"}
            label="Today"
            value={@section_card.summary.today}
            tone="orange"
          />

          <VisualComponents.summary_pill
            id={"garden-section-#{@section_card.section.id}-tomorrow"}
            label="Tomorrow"
            value={@section_card.summary.tomorrow}
            tone="amber"
          />
        </div>
      </div>

      <div class="mt-5">
        <div
          :if={Enum.empty?(@section_card.items)}
          id={"garden-section-empty-#{@section_card.section.id}"}
          class="garden-empty-inline rounded-[1.4rem] px-4 py-5 text-sm"
        >
          This section is ready for items, but nothing has been added yet.
        </div>

        <div
          :if={@section_card.items != []}
          id={"garden-section-items-#{@section_card.section.id}"}
          data-tile-layout="list"
          class="grid gap-3"
        >
          <ItemTileComponents.care_item_tile
            :for={item_card <- @section_card.items}
            id={"section-item-tile-#{item_card.item.id}"}
            item_card={item_card}
            tool_mode={@tool_mode}
            care_feedback={@care_feedback}
            today={@today}
          />
        </div>
      </div>
    </article>
    """
  end
end
