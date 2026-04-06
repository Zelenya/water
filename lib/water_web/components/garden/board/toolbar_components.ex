defmodule WaterWeb.Garden.Board.ToolbarComponents do
  use WaterWeb, :html

  alias WaterWeb.Garden.Shared.VisualComponents

  attr :id, :string, required: true
  attr :tool_mode, :atom, required: true
  attr :query_params, :map, required: true
  attr :can_add_item?, :boolean, required: true
  attr :mobile?, :boolean, default: false
  attr :compact?, :boolean, default: false
  attr :embedded?, :boolean, default: false

  def tool_bar(assigns) do
    ~H"""
    <nav
      id={@id}
      class={[
        !@embedded? && "garden-tool-dock rounded-[1.75rem]",
        @mobile? && "mx-auto flex max-w-md items-center justify-between gap-2 px-3 py-3",
        !@mobile? && @compact? && "flex flex-nowrap items-center gap-2",
        !@mobile? && !@compact? && "flex flex-wrap items-center gap-3 px-4 py-4"
      ]}
      aria-label="Garden tools"
    >
      <.tool_button
        id={"#{@id}-browse"}
        label="Browse"
        icon="layout-grid"
        active={@tool_mode == :browse}
        mode="browse"
        compact?={@compact?}
      />

      <.tool_button
        id={"#{@id}-water"}
        label="Water"
        icon="droplets"
        active={@tool_mode == :water}
        mode="water"
        compact?={@compact?}
      />

      <.tool_button
        id={"#{@id}-soil-check"}
        label="Soil Check"
        icon="shovel"
        active={@tool_mode == :soil_check}
        mode="soil_check"
        compact?={@compact?}
      />

      <.tool_button
        id={"#{@id}-needs-water"}
        label="Needs Water"
        icon="flag"
        active={@tool_mode == :manual_needs_watering}
        mode="manual_needs_watering"
        compact?={@compact?}
      />

      <%= if @can_add_item? do %>
        <.link
          id={"#{@id}-add-item"}
          patch={new_item_path(@query_params)}
          class={tool_button_classes(false, false, @compact?)}
        >
          <span class={[
            "garden-tool-icon inline-flex items-center justify-center rounded-2xl",
            @compact? && "size-9",
            !@compact? && "size-10"
          ]}>
            <.icon name="hero-plus" class={[@compact? && "size-4", !@compact? && "size-5"]} />
          </span>
          <span class="min-w-0 text-left">
            <span class="garden-tool-label block whitespace-nowrap text-sm font-semibold">
              Add Item
            </span>
            <span :if={!@compact?} class="garden-tool-note block text-xs">
              Create a new care card
            </span>
          </span>
        </.link>
      <% else %>
        <button
          id={"#{@id}-add-item"}
          type="button"
          disabled
          class={tool_button_classes(false, true, @compact?)}
        >
          <span class={[
            "garden-tool-icon-disabled inline-flex items-center justify-center rounded-2xl",
            @compact? && "size-9",
            !@compact? && "size-10"
          ]}>
            <.icon name="hero-plus" class={[@compact? && "size-4", !@compact? && "size-5"]} />
          </span>
          <span class="min-w-0 text-left">
            <span class="garden-tool-label block whitespace-nowrap text-sm font-semibold">
              Add Item
            </span>
            <span :if={!@compact?} class="garden-tool-note block text-xs">Add a section first</span>
          </span>
        </button>
      <% end %>
    </nav>
    """
  end

  attr :filter, :any, required: true
  attr :embedded?, :boolean, default: false

  # TODO: It's nice and copy-pasteable via path patch, but a bit jumpy. Consider refactoring.
  def filter_bar(assigns) do
    ~H"""
    <section
      id="garden-board-toolbar"
      class={[
        !@embedded? && "garden-board-toolbar rounded-[1.6rem] px-4 py-4 sm:px-5",
        @embedded? && "min-w-0"
      ]}
    >
      <div
        id="garden-board-filters"
        class={[
          "flex items-center gap-3",
          @embedded? && "min-w-0 flex-wrap justify-start xl:justify-end",
          !@embedded? && "flex-wrap"
        ]}
      >
        <div class="garden-filter-group flex max-w-full min-w-0 items-stretch overflow-x-auto overscroll-x-contain rounded-[1.6rem]">
          <.filter_chip
            id="filter-chip-all"
            label="All"
            selected={@filter == :all}
            patch={root_path(%{})}
          />
          <.filter_chip
            id="filter-chip-overdue"
            label="Overdue"
            selected={@filter == :overdue}
            patch={root_path(%{"filter" => "overdue"})}
          />
          <.filter_chip
            id="filter-chip-today"
            label="Today"
            selected={@filter == :today}
            patch={root_path(%{"filter" => "today"})}
          />
          <.filter_chip
            id="filter-chip-tomorrow"
            label="Soon"
            selected={@filter == :tomorrow}
            patch={root_path(%{"filter" => "tomorrow"})}
          />
          <.filter_chip
            id="filter-chip-no-schedule"
            label="No schedule"
            selected={@filter == :no_schedule}
            patch={root_path(%{"filter" => "no_schedule"})}
          />
        </div>
      </div>
    </section>
    """
  end

  attr :id, :string, required: true
  attr :label, :string, required: true
  attr :selected, :boolean, required: true
  attr :patch, :string, required: true

  defp filter_chip(assigns) do
    ~H"""
    <.link
      id={@id}
      patch={@patch}
      class={[
        "garden-filter-chip inline-flex shrink-0 items-center justify-center whitespace-nowrap px-4 py-2.5 text-sm font-medium transition",
        @selected && "garden-filter-chip-selected"
      ]}
    >
      {@label}
    </.link>
    """
  end

  attr :id, :string, required: true
  attr :label, :string, required: true
  attr :icon, :string, required: true
  attr :mode, :string, required: true
  attr :active, :boolean, default: false
  attr :disabled, :boolean, default: false
  attr :note, :string, default: nil
  attr :compact?, :boolean, default: false

  defp tool_button(assigns) do
    ~H"""
    <button
      id={@id}
      type="button"
      disabled={@disabled}
      aria-pressed={to_string(@active)}
      data-tool-mode={@mode}
      data-active={to_string(@active)}
      phx-click="switch_tool_mode"
      phx-value-mode={@mode}
      class={tool_button_classes(@active, @disabled, @compact?)}
    >
      <span class={[
        "inline-flex items-center justify-center rounded-2xl transition",
        @compact? && "size-9",
        !@compact? && "size-10",
        @active && "garden-tool-icon-active",
        !@active && !@disabled && "garden-tool-icon",
        @disabled && "garden-tool-icon-disabled"
      ]}>
        <VisualComponents.garden_icon
          name={@icon}
          class={[@compact? && "size-4", !@compact? && "size-5"]}
        />
      </span>
      <span class="min-w-0 text-left">
        <span class={[
          "garden-tool-label block whitespace-nowrap font-semibold",
          @compact? && "text-[0.95rem]",
          !@compact? && "text-sm",
          @disabled && "opacity-70"
        ]}>
          {@label}
        </span>
        <span :if={@note} class="garden-tool-note block text-xs">{@note}</span>
      </span>
    </button>
    """
  end

  @spec root_path(map()) :: String.t()
  defp root_path(params) when map_size(params) == 0, do: ~p"/"
  defp root_path(params), do: ~p"/?#{params}"

  @spec new_item_path(map()) :: String.t()
  defp new_item_path(params) when map_size(params) == 0, do: ~p"/items/new"
  defp new_item_path(params), do: ~p"/items/new?#{params}"

  @spec tool_button_classes(boolean(), boolean(), boolean()) :: [String.t()]
  defp tool_button_classes(active, disabled, compact?) do
    [
      "garden-tool-button flex min-w-0 items-center text-left transition",
      !compact? && "flex-1 gap-3 rounded-[1.35rem] px-3 py-3",
      compact? && "shrink-0 gap-2 rounded-[1.25rem] px-2.5 py-2.5",
      active && "garden-tool-button-active",
      disabled && "opacity-60"
    ]
  end
end
