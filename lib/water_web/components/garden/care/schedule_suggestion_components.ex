defmodule WaterWeb.Garden.Care.ScheduleSuggestionComponents do
  use WaterWeb, :html

  alias WaterWeb.Garden.Shared.{ModalComponents, SurfaceClasses}
  alias WaterWeb.Garden.State.ScheduleSuggestion

  attr :suggestion, :any, required: true

  def schedule_suggestion_modal(assigns) do
    ~H"""
    <ModalComponents.dismissable_overlay
      id="schedule-suggestion-modal"
      overlay_class={[
        SurfaceClasses.modal_overlay(),
        "fixed inset-0 z-50 overflow-y-auto px-4 py-8 backdrop-blur-sm sm:py-12"
      ]}
      wrapper_class="flex min-h-full items-start justify-center"
      surface_class={[SurfaceClasses.modal_surface(), "relative z-10 w-full max-w-2xl rounded-[2rem]"]}
      close_event="dismiss_schedule_suggestion"
      backdrop_id="schedule-suggestion-backdrop"
      backdrop_class="block h-full w-full cursor-default"
      close_label="Close schedule suggestion"
      role="dialog"
      aria-modal="true"
      aria-labelledby="schedule-suggestion-title"
    >
      <div class="garden-divider flex items-center justify-between gap-4 border-b px-6 py-5 sm:px-8">
        <div class="space-y-1">
          <p class="text-base-content/70 text-sm font-medium">Watering pattern found</p>
          <h2
            id="schedule-suggestion-title"
            class="text-base-content text-2xl font-semibold tracking-tight"
          >
            Suggest schedule
          </h2>
        </div>

        <button
          id="schedule-suggestion-close"
          type="button"
          phx-click="dismiss_schedule_suggestion"
          class="btn btn-circle btn-soft size-10"
          aria-label="Close schedule suggestion"
        >
          <.icon name="hero-x-mark" class="size-5" />
        </button>
      </div>

      <div class="space-y-5 px-6 py-6 sm:px-8">
        <div class="space-y-1">
          <h3
            id="schedule-suggestion-item"
            class="text-base-content text-lg font-semibold tracking-tight"
          >
            {@suggestion.item_card.item.name}
          </h3>
          <p class="text-base-content/70 text-sm leading-6">
            The last waterings point to {interval_copy(@suggestion.suggestion.suggested_interval_days)}.
          </p>
        </div>

        <div class="grid gap-3 sm:grid-cols-3">
          <.summary_card
            id="schedule-suggestion-current"
            label="Current"
            value={current_interval_copy(@suggestion)}
          />
          <.summary_card
            id="schedule-suggestion-proposed"
            label="Suggested"
            value={interval_copy(@suggestion.suggestion.suggested_interval_days)}
          />
          <.summary_card
            id="schedule-suggestion-next-due"
            label="Next due"
            value={short_date(@suggestion.suggestion.next_due_on)}
          />
        </div>

        <div
          id="schedule-suggestion-history"
          class={[SurfaceClasses.panel_soft(), "rounded-[1.5rem] px-4 py-3"]}
        >
          <div class="flex items-center justify-between gap-3">
            <p class="text-base-content text-sm font-semibold">Recent waterings</p>
            <.icon name="hero-calendar-days" class="text-base-content/70 size-4" />
          </div>
          <div class="mt-3 flex flex-wrap gap-2">
            <span
              :for={date <- @suggestion.suggestion.watering_dates}
              class="btn btn-xs btn-soft rounded-full px-3 text-xs font-semibold"
            >
              {short_date(date)}
            </span>
          </div>
        </div>

        <div class="flex flex-col-reverse gap-3 sm:flex-row sm:justify-end">
          <button
            id="schedule-suggestion-dismiss"
            type="button"
            phx-click="dismiss_schedule_suggestion"
            class="btn btn-sm btn-soft rounded-full px-4 text-sm font-medium"
          >
            Not now
          </button>
          <button
            id="schedule-suggestion-accept"
            type="button"
            phx-click="accept_schedule_suggestion"
            class="btn btn-sm btn-primary rounded-full px-4 text-sm font-semibold"
          >
            Use this schedule
          </button>
        </div>
      </div>
    </ModalComponents.dismissable_overlay>
    """
  end

  attr :id, :string, required: true
  attr :label, :string, required: true
  attr :value, :string, required: true

  defp summary_card(assigns) do
    ~H"""
    <div id={@id} class={[SurfaceClasses.panel_soft(), "rounded-[1.25rem] px-4 py-3"]}>
      <p class="text-base-content/70 text-xs font-semibold uppercase">{@label}</p>
      <p class="text-base-content mt-1 text-sm font-semibold">{@value}</p>
    </div>
    """
  end

  @spec current_interval_copy(ScheduleSuggestion.t()) :: String.t()
  defp current_interval_copy(%ScheduleSuggestion{suggestion: %{current_interval_days: nil}}),
    do: "No schedule"

  defp current_interval_copy(%ScheduleSuggestion{suggestion: %{current_interval_days: interval}}) do
    interval_copy(interval)
  end

  @spec interval_copy(pos_integer()) :: String.t()
  defp interval_copy(1), do: "Every day"
  defp interval_copy(interval), do: "Every #{interval} days"

  @spec short_date(Date.t()) :: String.t()
  defp short_date(%Date{} = date), do: Calendar.strftime(date, "%b %-d")
end
