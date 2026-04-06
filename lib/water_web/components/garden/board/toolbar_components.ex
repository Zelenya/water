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
        @mobile? && "garden-tool-dock-mobile mx-auto grid w-full max-w-sm grid-cols-5 gap-1.5 p-2",
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
        mobile?={@mobile?}
      />

      <.tool_button
        id={"#{@id}-water"}
        label="Water"
        icon="droplets"
        active={@tool_mode == :water}
        mode="water"
        compact?={@compact?}
        mobile?={@mobile?}
      />

      <.tool_button
        id={"#{@id}-soil-check"}
        label="Soil Check"
        icon="shovel"
        active={@tool_mode == :soil_check}
        mode="soil_check"
        compact?={@compact?}
        mobile?={@mobile?}
      />

      <.tool_button
        id={"#{@id}-needs-water"}
        label="Needs Water"
        icon="flag"
        active={@tool_mode == :manual_needs_watering}
        mode="manual_needs_watering"
        compact?={@compact?}
        mobile?={@mobile?}
      />

      <%= if @can_add_item? do %>
        <.link
          id={"#{@id}-add-item"}
          patch={new_item_path(@query_params)}
          aria-label="Add Item"
          title="Add Item"
          class={tool_button_classes(false, false, @compact?, @mobile?)}
        >
          <span class={[
            "garden-tool-icon inline-flex items-center justify-center rounded-2xl",
            @mobile? && "size-11",
            !@mobile? && @compact? && "size-9",
            !@mobile? && !@compact? && "size-10"
          ]}>
            <.icon
              name="hero-plus"
              class={[
                @mobile? && "size-5",
                !@mobile? && @compact? && "size-4",
                !@mobile? && !@compact? && "size-5"
              ]}
            />
          </span>
          <%= if @mobile? do %>
            <span class="sr-only">Add Item</span>
          <% else %>
            <span class="min-w-0 text-left">
              <span class="garden-tool-label block whitespace-nowrap text-sm font-semibold">
                Add Item
              </span>
              <span :if={!@compact?} class="garden-tool-note block text-xs">
                Create a new care card
              </span>
            </span>
          <% end %>
        </.link>
      <% else %>
        <button
          id={"#{@id}-add-item"}
          type="button"
          disabled
          aria-label="Add Item"
          title="Add Item"
          class={tool_button_classes(false, true, @compact?, @mobile?)}
        >
          <span class={[
            "garden-tool-icon-disabled inline-flex items-center justify-center rounded-2xl",
            @mobile? && "size-11",
            !@mobile? && @compact? && "size-9",
            !@mobile? && !@compact? && "size-10"
          ]}>
            <.icon
              name="hero-plus"
              class={[
                @mobile? && "size-5",
                !@mobile? && @compact? && "size-4",
                !@mobile? && !@compact? && "size-5"
              ]}
            />
          </span>
          <%= if @mobile? do %>
            <span class="sr-only">Add Item</span>
          <% else %>
            <span class="min-w-0 text-left">
              <span class="garden-tool-label block whitespace-nowrap text-sm font-semibold">
                Add Item
              </span>
              <span :if={!@compact?} class="garden-tool-note block text-xs">
                Add a section first
              </span>
            </span>
          <% end %>
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
        <div class="garden-filter-group flex w-full max-w-full min-w-0 items-stretch overflow-x-auto overscroll-x-contain rounded-[1.6rem] sm:w-auto">
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
            mobile_hidden?={true}
          />
        </div>
      </div>
    </section>
    """
  end

  attr :id, :string, required: true
  attr :label, :string, required: true
  attr :mobile_label, :string, default: nil
  attr :selected, :boolean, required: true
  attr :patch, :string, required: true
  attr :mobile_hidden?, :boolean, default: false
  attr :class, :any, default: nil

  defp filter_chip(assigns) do
    ~H"""
    <.link
      id={@id}
      patch={@patch}
      aria-label={@label}
      class={[
        "garden-filter-chip min-w-0 items-center justify-center whitespace-nowrap px-2.5 py-2 text-[0.8rem] font-medium transition sm:px-4 sm:py-2.5 sm:text-sm",
        !@mobile_hidden? && "inline-flex flex-1 sm:shrink-0 sm:flex-none",
        @mobile_hidden? && "hidden sm:inline-flex sm:shrink-0 sm:flex-none",
        @selected && "garden-filter-chip-selected",
        @class
      ]}
    >
      <%= if @mobile_label do %>
        <span class="sm:hidden">{@mobile_label}</span>
        <span class="hidden sm:inline">{@label}</span>
      <% else %>
        {@label}
      <% end %>
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
  attr :mobile?, :boolean, default: false

  defp tool_button(assigns) do
    ~H"""
    <button
      id={@id}
      type="button"
      disabled={@disabled}
      aria-label={@label}
      aria-pressed={to_string(@active)}
      data-tool-mode={@mode}
      data-active={to_string(@active)}
      phx-click="switch_tool_mode"
      phx-value-mode={@mode}
      title={@label}
      class={tool_button_classes(@active, @disabled, @compact?, @mobile?)}
    >
      <span class={[
        "inline-flex items-center justify-center rounded-2xl transition",
        @mobile? && "size-11",
        !@mobile? && @compact? && "size-9",
        !@mobile? && !@compact? && "size-10",
        @active && "garden-tool-icon-active",
        !@active && !@disabled && "garden-tool-icon",
        @disabled && "garden-tool-icon-disabled"
      ]}>
        <VisualComponents.garden_icon
          name={@icon}
          class={[
            @mobile? && "size-5",
            !@mobile? && @compact? && "size-4",
            !@mobile? && !@compact? && "size-5"
          ]}
        />
      </span>
      <%= if @mobile? do %>
        <span class="sr-only">{@label}</span>
      <% else %>
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
      <% end %>
    </button>
    """
  end

  @spec root_path(map()) :: String.t()
  defp root_path(params) when map_size(params) == 0, do: ~p"/"
  defp root_path(params), do: ~p"/?#{params}"

  @spec new_item_path(map()) :: String.t()
  defp new_item_path(params) when map_size(params) == 0, do: ~p"/items/new"
  defp new_item_path(params), do: ~p"/items/new?#{params}"

  @spec tool_button_classes(boolean(), boolean(), boolean(), boolean()) :: [String.t()]
  defp tool_button_classes(active, disabled, compact?, mobile?) do
    [
      "garden-tool-button flex min-w-0 items-center text-left transition",
      mobile? && "garden-tool-button-mobile justify-center rounded-[1.25rem] p-0",
      !compact? && !mobile? && "flex-1 gap-3 rounded-[1.35rem] px-3 py-3",
      compact? && !mobile? && "shrink-0 gap-2 rounded-[1.25rem] px-2.5 py-2.5",
      active && "garden-tool-button-active",
      disabled && "opacity-60"
    ]
  end
end
