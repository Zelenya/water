defmodule WaterWeb.Garden.Board.SectionComponents do
  use WaterWeb, :html

  alias WaterWeb.Garden.Board.ItemTileComponents
  alias WaterWeb.Garden.Shared.{SurfaceClasses, VisualComponents}
  alias WaterWeb.GardenLive.Navigation

  attr :section_card, :map, required: true
  attr :tool_mode, :atom, required: true
  attr :care_feedback, :any, default: nil
  attr :editing_section_id, :integer, default: nil
  attr :section_form, :any, default: nil
  attr :query_params, :map, default: %{}
  attr :today, :any, required: true
  attr :sortable?, :boolean, default: false

  def garden_section(assigns) do
    ~H"""
    <article
      id={"garden-section-#{@section_card.section.id}"}
      data-garden-section-id={@section_card.section.id}
      class={[
        SurfaceClasses.panel_card(),
        "garden-section-sortable-item rounded-[1.8rem] p-5",
        @sortable? && "garden-section-sortable"
      ]}
    >
      <div class="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div class="flex min-w-0 flex-1 items-center gap-3">
          <button
            :if={@sortable?}
            id={"garden-section-#{@section_card.section.id}-drag-handle"}
            type="button"
            class="garden-section-drag-handle inline-flex size-10 shrink-0 cursor-grab touch-none items-center justify-center rounded-full"
            aria-label={"Drag #{@section_card.section.name} to reorder sections"}
            title="Drag to move section"
          >
            <VisualComponents.garden_icon name="grip-vertical" class="size-4" />
          </button>

          <div class="min-w-0 flex-1">
            <.section_title
              :if={@editing_section_id == @section_card.section.id}
              section={@section_card.section}
              form={@section_form}
            />

            <h3
              :if={@editing_section_id != @section_card.section.id}
              id={"garden-section-#{@section_card.section.id}-title"}
              class="text-base-content truncate text-xl font-semibold leading-tight tracking-tight"
            >
              {@section_card.section.name}
            </h3>
          </div>
        </div>

        <div class="flex shrink-0 items-center gap-2 self-end sm:self-center">
          <div
            id={"garden-section-#{@section_card.section.id}-summary"}
            class="flex flex-nowrap items-center gap-1.5"
          >
            <VisualComponents.summary_pill
              id={"garden-section-#{@section_card.section.id}-overdue"}
              label="Overdue"
              value={@section_card.summary.overdue}
              tone="rose"
              compact={true}
            />

            <VisualComponents.summary_pill
              id={"garden-section-#{@section_card.section.id}-today"}
              label="Today"
              value={@section_card.summary.today}
              tone="orange"
              compact={true}
            />

            <VisualComponents.summary_pill
              id={"garden-section-#{@section_card.section.id}-tomorrow"}
              label="Tomorrow"
              value={@section_card.summary.tomorrow}
              tone="amber"
              compact={true}
            />
          </div>

          <.section_actions_menu section={@section_card.section} query_params={@query_params} />
        </div>
      </div>

      <div class="mt-3">
        <div
          id={"garden-section-items-#{@section_card.section.id}"}
          data-care-section-id={@section_card.section.id}
          data-sortable-enabled={to_string(@sortable?)}
          data-tile-layout="list"
          phx-hook="GardenCareSortable"
          class={[
            "garden-care-sortable-list grid gap-3",
            @section_card.items == [] && "garden-care-sortable-list-empty"
          ]}
        >
          <div
            :if={Enum.empty?(@section_card.items)}
            id={"garden-section-empty-#{@section_card.section.id}"}
            class="garden-empty-inline garden-care-sortable-empty rounded-[1.4rem] px-4 py-5 text-sm"
          >
            This section is ready for items, but nothing has been added yet.
          </div>

          <ItemTileComponents.care_item_tile
            :for={item_card <- @section_card.items}
            id={"section-item-tile-#{item_card.item.id}"}
            item_card={item_card}
            tool_mode={@tool_mode}
            care_feedback={@care_feedback}
            today={@today}
            sortable?={@sortable?}
          />
        </div>
      </div>
    </article>
    """
  end

  attr :section, :map, required: true
  attr :form, :any, required: true

  defp section_title(assigns) do
    ~H"""
    <.form
      for={@form}
      id={"garden-section-#{@section.id}-rename-form"}
      phx-change="validate_section"
      phx-submit="save_section"
      class="garden-section-rename-form flex flex-col gap-2 sm:flex-row sm:items-center"
    >
      <div class="min-w-0 flex-1">
        <.input
          field={@form[:name]}
          type="text"
          class="garden-section-title-input input input-sm text-base-content w-full text-xl font-semibold tracking-tight"
          autocomplete="off"
          required
        />
      </div>

      <div class="flex shrink-0 items-center gap-1">
        <button
          id={"garden-section-#{@section.id}-rename-submit"}
          type="submit"
          class="garden-section-rename-save btn btn-circle btn-sm"
          aria-label="Save section name"
        >
          <.icon name="hero-check" class="size-4" />
        </button>

        <button
          id={"garden-section-#{@section.id}-rename-cancel"}
          type="button"
          phx-click="cancel_section_rename"
          class="btn btn-circle btn-sm btn-ghost"
          aria-label="Cancel section rename"
        >
          <.icon name="hero-x-mark" class="size-4" />
        </button>
      </div>
    </.form>
    """
  end

  attr :section, :map, required: true
  attr :query_params, :map, required: true

  defp section_actions_menu(assigns) do
    ~H"""
    <div
      id={"garden-section-#{@section.id}-actions"}
      class="dropdown dropdown-end"
    >
      <button
        id={"garden-section-#{@section.id}-actions-trigger"}
        type="button"
        tabindex="0"
        class="btn btn-circle btn-sm btn-ghost"
        aria-label={"Open actions for #{@section.name}"}
      >
        <.icon name="hero-ellipsis-vertical" class="size-5" />
      </button>

      <ul
        tabindex="0"
        class="dropdown-content menu bg-base-100 rounded-box z-20 mt-2 w-44 p-2 shadow"
      >
        <li>
          <.link
            id={"garden-section-#{@section.id}-add-item"}
            patch={Navigation.item_new_path(add_item_query_params(@section, @query_params))}
          >
            <.icon name="hero-plus" class="size-4" /> Add care item
          </.link>
        </li>
        <li>
          <button
            id={"garden-section-#{@section.id}-rename"}
            type="button"
            phx-click="start_section_rename"
            phx-value-section-id={@section.id}
          >
            <.icon name="hero-pencil-square" class="size-4" /> Rename
          </button>
        </li>
        <li>
          <button
            id={"garden-section-#{@section.id}-delete"}
            type="button"
            phx-click="delete_section"
            phx-value-section-id={@section.id}
            data-confirm={"Delete #{@section.name}? This removes every care item and care event in this section."}
            class="text-error"
          >
            <.icon name="hero-trash" class="size-4" /> Delete
          </button>
        </li>
      </ul>
    </div>
    """
  end

  @spec add_item_query_params(map(), map()) :: map()
  defp add_item_query_params(section, query_params) do
    Map.put(query_params, "section_id", section.id)
  end
end
