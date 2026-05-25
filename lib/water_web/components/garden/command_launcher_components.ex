defmodule WaterWeb.Garden.CommandLauncherComponents do
  use WaterWeb, :html

  alias WaterWeb.Garden.CommandLauncher
  alias WaterWeb.Garden.CommandLauncher.Entry
  alias WaterWeb.Garden.Shared.VisualComponents
  alias WaterWeb.Garden.State.CommandLauncher, as: LauncherState

  @launcher_overlay_class "bg-[color-mix(in_oklab,var(--garden-overlay)_88%,transparent)] backdrop-blur-[12px]"
  @launcher_surface_class "border border-[var(--garden-border)] bg-[var(--garden-surface-modal)] shadow-[var(--garden-shadow-modal)] min-h-[78vh] max-h-[calc(100dvh-1rem)] md:min-h-0 md:max-h-[min(70vh,42rem)]"
  @launcher_search_class "border-[var(--garden-border)] bg-[color-mix(in_oklab,var(--garden-pill-bg)_86%,var(--garden-surface-muted))] text-[var(--garden-text-primary)]"
  @launcher_trigger_class "border border-[var(--garden-border)] bg-[color-mix(in_oklab,var(--garden-pill-bg)_88%,white)] text-[var(--garden-text-primary)] shadow-[var(--garden-shadow-sm)]"
  @launcher_row_icon_class "border-[color-mix(in_oklab,var(--garden-border)_78%,transparent)] bg-[color-mix(in_oklab,var(--garden-pill-bg)_72%,transparent)]"
  @launcher_row_idle_class "hover:border-[var(--garden-border)] hover:bg-[color-mix(in_oklab,var(--garden-pill-bg)_70%,transparent)]"
  @launcher_row_selected_class "border-[var(--garden-water-highlight-border)] bg-[color-mix(in_oklab,var(--garden-surface-subtle)_82%,white)] shadow-[inset_0_0_0_1px_var(--garden-water-highlight-ring)]"
  @launcher_row_disabled_class "opacity-[0.62] [&>span:first-child]:bg-[color-mix(in_oklab,var(--garden-surface-muted)_88%,transparent)]"
  @launcher_current_class "border border-[var(--garden-accent-border)] bg-[color-mix(in_oklab,var(--garden-accent-bg)_84%,transparent)] text-[var(--garden-accent-text)]"
  @launcher_empty_class "border border-[var(--garden-border)] bg-[color-mix(in_oklab,var(--garden-surface-history)_84%,transparent)]"

  def trigger_button(assigns) do
    ~H"""
    <div class="flex items-center gap-2">
      <button
        id="garden-command-launcher-trigger-mobile"
        type="button"
        phx-click="toggle_command_launcher"
        class="btn btn-circle btn-sm btn-soft md:hidden"
        aria-label="Open command launcher"
      >
        <.icon name="hero-magnifying-glass" class="size-4" />
      </button>

      <button
        id="garden-command-launcher-trigger"
        type="button"
        phx-click="toggle_command_launcher"
        class={[
          launcher_trigger_class(),
          "btn btn-sm btn-soft hidden items-center gap-3 md:inline-flex"
        ]}
      >
        <span class="inline-flex items-center gap-2">
          <.icon name="hero-magnifying-glass" class="size-4" />
          <span>Search...</span>
        </span>
        <span class="inline-flex items-center gap-1">
          <kbd class="kbd kbd-xs">⌘</kbd>
          <kbd class="kbd kbd-xs">K</kbd>
        </span>
      </button>
    </div>
    """
  end

  attr :launcher, LauncherState, required: true

  @doc """
  Render the launcher overlay when state says it is open
  """
  def launcher(assigns) do
    command_results = CommandLauncher.command_results(assigns.launcher)
    item_results = CommandLauncher.item_results(assigns.launcher)
    selected_entry_id = selected_entry_id(assigns.launcher)

    assigns =
      assigns
      |> assign(:command_results, command_results)
      |> assign(:item_results, item_results)
      |> assign(:selected_entry_id, selected_entry_id)

    ~H"""
    <div
      :if={@launcher.open?}
      id="garden-command-launcher"
      class={[launcher_overlay_class(), "modal modal-open modal-bottom md:modal-middle"]}
      role="dialog"
      aria-modal="true"
      aria-labelledby="garden-command-launcher-title"
      phx-hook="GardenCommandLauncher"
    >
      <div class={[
        launcher_surface_class(),
        "modal-box relative flex w-full max-w-none flex-col overflow-hidden rounded-t-[1.75rem] p-0 md:max-w-2xl md:rounded-[2rem]"
      ]}>
        <%!-- Header --%>
        <div class="border-b border-[var(--garden-divider)] px-4 py-4 sm:px-5">
          <div class="flex items-center gap-3">
            <form
              id="garden-command-launcher-form"
              phx-change="change_command_launcher_query"
              class="min-w-0 flex-1"
            >
              <label
                for="garden-command-launcher-input"
                class={[
                  launcher_search_class(),
                  "input input-bordered flex min-h-12 w-full items-center gap-3 rounded-[1.3rem] px-3"
                ]}
              >
                <span class="sr-only">Search for a command or an item</span>
                <.icon name="hero-magnifying-glass" class="size-4 shrink-0" />
                <input
                  id="garden-command-launcher-input"
                  name="query"
                  type="text"
                  value={@launcher.query}
                  placeholder="Search commands and items"
                  autocomplete="off"
                  autofocus
                  class="grow border-0 bg-transparent p-0 text-sm outline-none placeholder:text-base-content/55"
                />

                <div class="hidden items-center gap-1 md:flex">
                  <kbd class="kbd kbd-xs">⌘</kbd>
                  <kbd class="kbd kbd-xs">K</kbd>
                </div>
              </label>
            </form>

            <button
              id="garden-command-launcher-close"
              type="button"
              phx-click="close_command_launcher"
              class="btn btn-circle btn-sm btn-ghost"
              aria-label="Close command launcher"
            >
              <.icon name="hero-x-mark" class="size-5" />
            </button>
          </div>
        </div>

        <%!-- Body --%>
        <div class="garden-command-launcher-body overflow-y-auto px-3 py-3 sm:px-4 sm:py-4">
          <h2 id="garden-command-launcher-title" class="sr-only">Command launcher</h2>

          <div id="garden-command-launcher-results" class="space-y-5">
            <.result_group
              :if={@command_results != []}
              id="garden-command-launcher-commands"
              title="Commands"
              results={@command_results}
              selected_entry_id={@selected_entry_id}
            />

            <.result_group
              :if={@item_results != []}
              id="garden-command-launcher-items"
              title="Items"
              results={@item_results}
              selected_entry_id={@selected_entry_id}
            />

            <div
              :if={@launcher.results == []}
              id="garden-command-launcher-empty"
              class={[launcher_empty_class(), "rounded-[1.5rem] px-4 py-8 text-center"]}
            >
              <p class="text-base-content text-base font-semibold">Nothing matches this search</p>
              <p class="text-base-content/70 mt-1 text-sm">
                Retry searching for a command, item name, or section name.
              </p>
            </div>
          </div>
        </div>
      </div>

      <form method="dialog" class="modal-backdrop">
        <button
          id="garden-command-launcher-backdrop"
          type="button"
          phx-click="close_command_launcher"
          class="block h-full w-full cursor-default"
          aria-label="Close command launcher"
        >
          <span class="sr-only">Close command launcher</span>
        </button>
      </form>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :title, :string, required: true
  attr :results, :list, required: true
  attr :selected_entry_id, :string, default: nil

  defp result_group(assigns) do
    ~H"""
    <section id={@id} class="space-y-2">
      <header class="px-2">
        <h3 class="text-base-content/55 text-xs font-semibold uppercase tracking-[0.18em]">
          {@title}
        </h3>
      </header>

      <div class="list gap-1">
        <.result_row
          :for={entry <- @results}
          entry={entry}
          selected?={@selected_entry_id == entry.id}
        />
      </div>
    </section>
    """
  end

  attr :entry, Entry, required: true
  attr :selected?, :boolean, required: true

  defp result_row(assigns) do
    ~H"""
    <button
      id={"garden-command-launcher-entry-#{@entry.id}"}
      type="button"
      disabled={!@entry.selectable?}
      phx-click="execute_command_launcher_entry"
      phx-value-id={@entry.id}
      class={[
        "list-row w-full items-start gap-3 rounded-[1.3rem] border border-transparent px-3 py-3 text-left transition sm:px-4",
        @entry.selectable? && @selected? && launcher_row_selected_class(),
        @entry.selectable? && !@selected? && launcher_row_idle_class(),
        !@entry.selectable? && launcher_row_disabled_class()
      ]}
    >
      <span class={[
        launcher_row_icon_class(),
        "mt-0.5 inline-flex size-10 shrink-0 items-center justify-center rounded-2xl border"
      ]}>
        <%= if @entry.icon_type == :garden do %>
          <VisualComponents.garden_icon name={@entry.icon_name} class="size-5" />
        <% else %>
          <.icon name={@entry.icon_name} class="size-5" />
        <% end %>
      </span>

      <span class="list-col-grow min-w-0 space-y-1">
        <span class="flex min-w-0 items-center gap-2">
          <span class="truncate text-sm font-semibold">{@entry.title}</span>
          <%!-- optional current badge for a command/tool --%>
          <span
            :if={@entry.current?}
            class={[
              launcher_current_class(),
              "rounded-full px-2 py-0.5 text-[0.68rem] font-semibold uppercase tracking-[0.16em]"
            ]}
          >
            Current
          </span>
          <%!-- optional status badge for a care item --%>
          <VisualComponents.status_badge
            :if={@entry.group == :items and @entry.status != nil}
            status={@entry.status}
            quiet={true}
          />
        </span>
        <span class="text-base-content/70 block text-sm leading-5">
          {@entry.subtitle}
        </span>
      </span>
    </button>
    """
  end

  @spec selected_entry_id(LauncherState.t()) :: nil | String.t()
  defp selected_entry_id(%LauncherState{} = launcher) do
    case CommandLauncher.selected_entry(launcher) do
      %Entry{id: entry_id} -> entry_id
      nil -> nil
    end
  end

  defp launcher_overlay_class, do: @launcher_overlay_class
  defp launcher_surface_class, do: @launcher_surface_class
  defp launcher_search_class, do: @launcher_search_class
  defp launcher_trigger_class, do: @launcher_trigger_class
  defp launcher_row_icon_class, do: @launcher_row_icon_class
  defp launcher_row_idle_class, do: @launcher_row_idle_class
  defp launcher_row_selected_class, do: @launcher_row_selected_class
  defp launcher_row_disabled_class, do: @launcher_row_disabled_class
  defp launcher_current_class, do: @launcher_current_class
  defp launcher_empty_class, do: @launcher_empty_class
end
