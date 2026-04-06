defmodule WaterWeb.Layouts do
  @moduledoc """
  Shared application chrome for the LiveView surfaces in this app.

  The garden UI keeps product-specific controls inside feature components and
  reserves this module for concerns that should stay consistent across screens:
  the app header, the active-member status, theme controls, and flash handling.
  That split keeps feature modules focused on board behavior instead of
  re-explaining shell-level UI every time a new page or modal is added.
  """
  use WaterWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  In this project the layout is intentionally thin. It provides a stable frame
  around the garden experience while leaving the main product interaction inside
  `GardenLive`.

  Two things are worth knowing when onboarding:

  - `active_member` comes from authenticated session state and is surfaced here
    so every screen can reinforce "who is acting" without duplicating header UI.
  - flashes are rendered outside the main content container so feature modules
    never need to reserve their own space for global feedback.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  attr :active_member, :map, default: nil, doc: "the active household member"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <header class="garden-app-header border-b border-base-300 bg-base-100/90 backdrop-blur">
      <div class="mx-auto flex max-w-6xl items-center justify-between gap-4 px-4 py-4 sm:px-6 lg:px-8">
        <.link navigate={~p"/"} class="min-w-0">
          <p class="text-lg font-semibold tracking-tight text-base-content">
            Don't forget to drink some water
          </p>
        </.link>

        <div class="flex items-center gap-3">
          <span
            :if={@active_member}
            id="header-active-member"
            class="garden-pill inline-flex items-center gap-2 rounded-full px-3 py-1.5 text-sm font-medium shadow-sm"
          >
            <span
              class="size-2.5 rounded-full"
              style={"background-color: #{@active_member.color || "#4f7b47"}"}
            />
            <span class="sm:hidden">{@active_member.name}</span>
            <span class="hidden sm:inline">Active member: {@active_member.name}</span>
          </span>
          <.theme_toggle />
        </div>
      </div>
    </header>

    <main class="garden-app-main px-4 py-8 sm:px-6 lg:px-8">
      <div class="mx-auto max-w-6xl space-y-4">
        {render_slot(@inner_block)}
      </div>
    </main>

    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  The toggle dispatches a browser event instead of round-tripping through the
  server. That keeps theme changes instant, persists them across pages via
  `localStorage`, and avoids coupling a purely presentational preference to
  LiveView assigns.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div
      id="theme-toggle"
      class="card relative flex flex-row items-center rounded-full border-2 border-base-300 bg-base-300"
    >
      <%!-- The slider position is driven entirely by the root `data-theme` attribute. --%>
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 transition-[left]" />

      <button
        id="theme-toggle-system"
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        id="theme-toggle-light"
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        id="theme-toggle-dark"
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end
