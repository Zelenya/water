defmodule WaterWeb.Garden.Shared.ModalComponents do
  use WaterWeb, :html

  attr :id, :string, required: true
  attr :overlay_class, :any, required: true
  attr :wrapper_class, :any, required: true
  attr :surface_class, :any, required: true
  attr :close_patch, :string, default: nil
  attr :close_event, :string, default: nil
  attr :backdrop_id, :string, default: nil
  attr :backdrop_class, :any, default: nil
  attr :close_label, :string, default: "Close overlay"
  attr :rest, :global
  slot :inner_block, required: true

  def dismissable_overlay(assigns) do
    ~H"""
    <div id={@id} class={@overlay_class} {@rest}>
      <div class="absolute inset-0">
        <.overlay_backdrop
          backdrop_id={@backdrop_id}
          close_patch={@close_patch}
          close_event={@close_event}
          class={@backdrop_class}
          close_label={@close_label}
        />
      </div>

      <div class={@wrapper_class}>
        <div class={@surface_class}>
          {render_slot(@inner_block)}
        </div>
      </div>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :title, :string, required: true
  attr :close_patch, :string, required: true
  slot :inner_block, required: true

  def modal_frame(assigns) do
    ~H"""
    <.dismissable_overlay
      id={@id}
      overlay_class="garden-modal-overlay fixed inset-0 z-40 overflow-y-auto px-4 py-8 backdrop-blur-sm sm:py-12"
      wrapper_class="flex min-h-full items-start justify-center"
      surface_class="garden-modal-surface relative z-10 w-full max-w-2xl rounded-[2rem]"
      close_patch={@close_patch}
      backdrop_id="garden-modal-backdrop"
      backdrop_class="block h-full w-full cursor-default"
      close_label="Close modal"
    >
      <div class="garden-divider flex items-center justify-between gap-4 border-b px-6 py-5 sm:px-8">
        <h2 class="garden-heading text-2xl font-semibold tracking-tight">{@title}</h2>
        <.link
          id="garden-modal-close"
          patch={@close_patch}
          class="garden-button-secondary inline-flex size-10 items-center justify-center rounded-full"
          aria-label="Close modal"
        >
          <.icon name="hero-x-mark" class="size-5" />
        </.link>
      </div>

      <div class="px-6 py-6 sm:px-8">
        {render_slot(@inner_block)}
      </div>
    </.dismissable_overlay>
    """
  end

  attr :backdrop_id, :string, default: nil
  attr :close_patch, :string, default: nil
  attr :close_event, :string, default: nil
  attr :class, :any, default: nil
  attr :close_label, :string, default: "Close overlay"

  defp overlay_backdrop(%{close_patch: close_patch} = assigns) when is_binary(close_patch) do
    ~H"""
    <.link id={@backdrop_id} patch={@close_patch} class={@class} aria-label={@close_label}>
      <span class="sr-only">{@close_label}</span>
    </.link>
    """
  end

  defp overlay_backdrop(%{close_event: close_event} = assigns) when is_binary(close_event) do
    ~H"""
    <button
      id={@backdrop_id}
      type="button"
      phx-click={@close_event}
      class={@class}
      aria-label={@close_label}
    />
    """
  end

  defp overlay_backdrop(assigns) do
    ~H"""
    <span id={@backdrop_id} class={@class} aria-hidden="true"></span>
    """
  end
end
