defmodule WaterWeb.Garden.Care.ActionComponents do
  use WaterWeb, :html

  alias Water.Garden.CareItemCard
  alias WaterWeb.Garden.State.CareAction

  attr :care_action, :any, required: true
  attr :today, :any, required: true

  def care_action_modal(assigns) do
    ~H"""
    <div
      id="care-action-modal"
      class="garden-modal-overlay fixed inset-0 z-50 overflow-y-auto px-4 py-8 backdrop-blur-sm sm:py-12"
      role="dialog"
      aria-modal="true"
      aria-labelledby="care-action-modal-title"
    >
      <div class="flex min-h-full items-start justify-center">
        <button
          id="care-action-modal-backdrop"
          type="button"
          phx-click="cancel_care_action"
          class="absolute inset-0 block h-full w-full cursor-default"
          aria-label="Close care action"
        />

        <section class="garden-modal-surface relative z-10 w-full max-w-2xl rounded-[2rem]">
          <div class="garden-divider flex items-center justify-between gap-4 border-b px-6 py-5 sm:px-8">
            <div class="space-y-1">
              <h2
                id="care-action-modal-title"
                class="garden-heading text-2xl font-semibold tracking-tight"
              >
                {care_action_heading(@care_action.kind)}
              </h2>
            </div>

            <button
              id="care-action-modal-close"
              type="button"
              phx-click="cancel_care_action"
              class="garden-button-secondary inline-flex size-10 items-center justify-center rounded-full"
              aria-label="Close care action"
            >
              <.icon name="hero-x-mark" class="size-5" />
            </button>
          </div>

          <div class="px-6 py-6 sm:px-8">
            <.care_action_content
              id_prefix="care-action-modal"
              care_action={@care_action}
              today={@today}
            />
          </div>
        </section>
      </div>
    </div>
    """
  end

  attr :id_prefix, :string, required: true
  attr :care_action, :any, required: true
  attr :today, :any, required: true

  # Via soil-check tool, we show the subset of care actions.
  # On the item care details, we show all the care actions for that item.
  defp care_action_content(assigns) do
    ~H"""
    <div class="space-y-4">
      <div class="space-y-1">
        <h3 class="garden-heading text-lg font-semibold tracking-tight">
          {@care_action.item_card.item.name}
        </h3>
        <p class="garden-text-muted text-sm">
          {care_action_body(@care_action, @today)}
        </p>
      </div>

      <%= cond do %>
        <% @care_action.mode == :custom_days -> %>
          <.postpone_days_form id_prefix={@id_prefix} care_action={@care_action} />
        <% @care_action.mode == :custom_date -> %>
          <.postpone_date_form id_prefix={@id_prefix} care_action={@care_action} />
        <% true -> %>
          <div class="space-y-3">
            <.schedule_preset_options
              :if={@care_action.kind == :schedule_watering}
              id_prefix={@id_prefix}
            />
            <.postpone_options id_prefix={@id_prefix} care_action={@care_action} />
          </div>
      <% end %>
    </div>
    """
  end

  attr :id_prefix, :string, required: true
  attr :care_action, :any, required: true

  defp postpone_days_form(assigns) do
    ~H"""
    <.form
      for={@care_action.form}
      id={"#{@id_prefix}-#{action_prefix(@care_action.kind)}-custom-form"}
      phx-change="change_schedule_custom_days"
      phx-submit="submit_schedule_custom_days"
      class="space-y-3"
    >
      <.input
        field={@care_action.form[:days]}
        id={"#{@id_prefix}-#{action_prefix(@care_action.kind)}-days"}
        type="number"
        label="Custom days"
        min="1"
      />
      <p
        :if={@care_action.error}
        id={"#{@id_prefix}-#{action_prefix(@care_action.kind)}-error"}
        class="text-sm text-[var(--garden-status-rose-text)]"
      >
        {@care_action.error}
      </p>
      <div class="flex flex-wrap gap-3">
        <button
          id={"#{@id_prefix}-#{action_prefix(@care_action.kind)}-custom-submit"}
          type="submit"
          class="garden-button-primary inline-flex items-center justify-center rounded-full px-4 py-2 text-sm font-semibold"
        >
          Save delay
        </button>
        <button
          id={"#{@id_prefix}-#{action_prefix(@care_action.kind)}-custom-back"}
          type="button"
          phx-click="show_schedule_picker"
          class="garden-button-secondary inline-flex items-center justify-center rounded-full px-4 py-2 text-sm font-medium"
        >
          Back
        </button>
      </div>
    </.form>
    """
  end

  attr :id_prefix, :string, required: true
  attr :care_action, :any, required: true

  defp postpone_date_form(assigns) do
    ~H"""
    <.form
      for={@care_action.form}
      id={"#{@id_prefix}-#{action_prefix(@care_action.kind)}-date-form"}
      phx-change="change_schedule_target"
      phx-submit="submit_schedule_target"
      class="space-y-3"
    >
      <.input
        field={@care_action.form[:target_on]}
        id={"#{@id_prefix}-#{action_prefix(@care_action.kind)}-target-on"}
        type="date"
        label={target_on_label(@care_action.kind)}
      />
      <p
        :if={@care_action.error}
        id={"#{@id_prefix}-#{action_prefix(@care_action.kind)}-error"}
        class="text-sm text-[var(--garden-status-rose-text)]"
      >
        {@care_action.error}
      </p>
      <div class="flex flex-wrap gap-3">
        <button
          id={"#{@id_prefix}-#{action_prefix(@care_action.kind)}-date-submit"}
          type="submit"
          class="garden-button-primary inline-flex items-center justify-center rounded-full px-4 py-2 text-sm font-semibold"
        >
          Save date
        </button>
        <button
          id={"#{@id_prefix}-#{action_prefix(@care_action.kind)}-date-back"}
          type="button"
          phx-click="show_schedule_picker"
          class="garden-button-secondary inline-flex items-center justify-center rounded-full px-4 py-2 text-sm font-medium"
        >
          Back
        </button>
      </div>
    </.form>
    """
  end

  attr :id_prefix, :string, required: true

  defp schedule_preset_options(assigns) do
    ~H"""
    <button
      id={"#{@id_prefix}-schedule-today"}
      type="button"
      phx-click="submit_schedule_preset"
      phx-value-preset="today"
      class="garden-action-option garden-action-option-warm flex w-full items-center justify-between rounded-[1.25rem] px-4 py-3 text-left"
    >
      <span>
        <span class="garden-text-primary block text-sm font-semibold">Today</span>
        <span class="garden-text-warm block text-xs">
          Needs to be watered right away
        </span>
      </span>
      <.icon name="hero-sun" class="garden-text-warm size-4" />
    </button>

    <button
      id={"#{@id_prefix}-schedule-tomorrow"}
      type="button"
      phx-click="submit_schedule_preset"
      phx-value-preset="tomorrow"
      class="garden-action-option garden-action-option-soft flex w-full items-center justify-between rounded-[1.25rem] px-4 py-3 text-left"
    >
      <span>
        <span class="garden-text-primary block text-sm font-semibold">Tomorrow</span>
        <span class="garden-text-muted block text-xs">
          Can wait another day
        </span>
      </span>
      <.icon name="hero-calendar-days" class="garden-text-muted size-4" />
    </button>
    """
  end

  attr :id_prefix, :string, required: true
  attr :care_action, :any, required: true

  defp postpone_options(assigns) do
    ~H"""
    <button
      :if={usual_interval_available?(@care_action)}
      id={"#{@id_prefix}-#{action_prefix(@care_action.kind)}-usual"}
      type="button"
      phx-click="submit_schedule_usual"
      class="garden-action-option garden-action-option-soft flex w-full items-center justify-between rounded-[1.25rem] px-4 py-3 text-left"
    >
      <span>
        <span class="garden-text-primary block text-sm font-semibold">Usual interval</span>
        <span class="garden-text-muted block text-xs">
          Delay by {@care_action.item_card.item.watering_interval_days} days
        </span>
      </span>
      <.icon name="hero-arrow-right" class="garden-text-muted size-4" />
    </button>

    <button
      id={"#{@id_prefix}-#{action_prefix(@care_action.kind)}-custom-toggle"}
      type="button"
      phx-click="show_schedule_custom_days"
      class="garden-action-option flex w-full items-center justify-between rounded-[1.25rem] px-4 py-3 text-left"
    >
      <span>
        <span class="garden-text-primary block text-sm font-semibold">Custom days</span>
        <span class="garden-text-muted block text-xs">
          Delay by custom number of days
        </span>
      </span>
      <.icon name="hero-adjustments-horizontal" class="garden-text-muted size-4" />
    </button>

    <button
      id={"#{@id_prefix}-#{action_prefix(@care_action.kind)}-date-toggle"}
      type="button"
      phx-click="show_schedule_date"
      class="garden-action-option flex w-full items-center justify-between rounded-[1.25rem] px-4 py-3 text-left"
    >
      <span>
        <span class="garden-text-primary block text-sm font-semibold">Pick date</span>
        <span class="garden-text-muted block text-xs">
          Choose the exact next due date
        </span>
      </span>
      <.icon name="hero-calendar" class="garden-text-muted size-4" />
    </button>
    """
  end

  @spec care_action_heading(CareAction.kind()) :: String.t()
  defp care_action_heading(:soil_check), do: "Soil check"
  defp care_action_heading(:schedule_watering), do: "Schedule watering"

  @spec care_action_body(CareAction.t(), Date.t()) :: String.t()
  defp care_action_body(
         %CareAction{
           kind: :soil_check,
           item_card: %CareItemCard{effective_due_on: %Date{} = due_on}
         },
         _today
       ) do
    "Reschedule the watering due date (the current due date is #{short_date(due_on)})"
  end

  defp care_action_body(%CareAction{kind: :soil_check}, %Date{} = today) do
    "Set a future reminder from today (#{short_date(today)}) or pick an exact date."
  end

  defp care_action_body(
         %CareAction{
           kind: :schedule_watering,
           item_card: %CareItemCard{effective_due_on: %Date{} = due_on}
         },
         %Date{} = today
       ) do
    "Reschedule the watering due date (the current due date is #{short_date(due_on)}, today is #{short_date(today)})"
  end

  defp care_action_body(%CareAction{kind: :schedule_watering}, %Date{} = today) do
    "Set a one-off watering reminder from today (#{short_date(today)}) or pick an exact due date."
  end

  @spec action_prefix(CareAction.kind()) :: String.t()
  defp action_prefix(:soil_check), do: "soil"
  defp action_prefix(:schedule_watering), do: "schedule"

  @spec target_on_label(CareAction.kind()) :: String.t()
  defp target_on_label(:soil_check), do: "Delay until"
  defp target_on_label(:schedule_watering), do: "Next due date"

  @spec short_date(Date.t()) :: String.t()
  defp short_date(%Date{} = date), do: Calendar.strftime(date, "%b %-d")

  @spec usual_interval_available?(CareAction.t()) :: boolean()
  defp usual_interval_available?(%CareAction{
         item_card: %CareItemCard{item: %{watering_interval_days: interval}}
       })
       when is_integer(interval) and interval > 0,
       do: true

  defp usual_interval_available?(%CareAction{}), do: false
end
