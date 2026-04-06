defmodule WaterWeb.Garden.Shared.ModalComponents do
  use WaterWeb, :html

  attr :id, :string, required: true
  attr :title, :string, required: true
  attr :close_patch, :string, required: true
  slot :inner_block, required: true

  def modal_frame(assigns) do
    ~H"""
    <div
      id={@id}
      class="garden-modal-overlay fixed inset-0 z-40 overflow-y-auto px-4 py-8 backdrop-blur-sm sm:py-12"
    >
      <div class="flex min-h-full items-start justify-center">
        <div class="absolute inset-0">
          <.link
            id="garden-modal-backdrop"
            patch={@close_patch}
            class="block h-full w-full cursor-default"
            aria-label="Close modal"
          >
            <span class="sr-only">Close modal</span>
          </.link>
        </div>

        <div class="garden-modal-surface relative z-10 w-full max-w-2xl rounded-[2rem]">
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
        </div>
      </div>
    </div>
    """
  end
end
