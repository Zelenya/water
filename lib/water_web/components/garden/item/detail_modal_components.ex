defmodule WaterWeb.Garden.Item.DetailModalComponents do
  use WaterWeb, :html

  alias Water.Garden.{CareEvent, CareItem, CareItemCard, Section}
  alias Water.Households.Member
  alias WaterWeb.Garden.Shared.{ModalComponents, VisualComponents}
  alias WaterWeb.Garden.State.CareFeedback

  attr :id, :string, required: true
  attr :modal, :any, required: true
  attr :section_lookup, :map, required: true
  attr :edit_patch, :string, required: true
  attr :care_feedback, :any, default: nil
  attr :today, :any, required: true

  def item_detail_modal(assigns) do
    ~H"""
    <ModalComponents.modal_frame id={@id} title={@modal.title} close_patch={@modal.close_path}>
      <div class="space-y-4">
        <div class="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
          <div class="space-y-2">
            <div class="flex items-center gap-3">
              <span class="garden-item-type-chip inline-flex size-10 items-center justify-center rounded-2xl">
                <VisualComponents.garden_icon
                  name={VisualComponents.item_icon_name(@modal.item_detail.item_card.item.type)}
                  class="size-5"
                />
              </span>
              <div>
                <p class="garden-text-primary text-base font-semibold">
                  {section_name(@section_lookup, @modal.item_detail.item_card.item.section_id)}
                </p>
              </div>
            </div>
          </div>
          <div class="flex flex-row items-center gap-2 inline-flex justify-center py-2.5">
            <VisualComponents.status_badge status={@modal.item_detail.item_card.status} />
          </div>
        </div>

        <div
          id="item-detail-quick-actions"
          class="garden-panel-soft rounded-[1.4rem] p-2"
        >
          <div class="flex flex-col justify-center gap-1 sm:flex-row sm:flex-wrap">
            <button
              id="item-detail-water"
              type="button"
              phx-click="water_from_detail"
              class="garden-button-primary inline-flex items-center justify-center gap-2 rounded-full px-4 py-2.5 text-sm font-semibold"
            >
              <VisualComponents.garden_icon name="droplets" class="size-5" /> Water now
            </button>

            <button
              id="item-detail-schedule-watering"
              type="button"
              phx-click="open_detail_care_action"
              phx-value-kind="schedule_watering"
              class="garden-button-secondary inline-flex items-center justify-center gap-2 rounded-full px-4 py-2.5 text-sm font-semibold"
            >
              <VisualComponents.garden_icon name="calendar-1" class="size-5" /> Schedule one
            </button>

            <button
              id="item-detail-clear-schedule"
              type="button"
              phx-click="clear_schedule_from_detail"
              class="garden-button-secondary inline-flex items-center justify-center gap-2 rounded-full px-4 py-2.5 text-sm font-semibold"
            >
              <.icon name="hero-pause-circle" class="size-5" /> Clear schedule
            </button>

            <.link
              id="item-detail-edit"
              patch={@edit_patch}
              class="garden-button-secondary inline-flex items-center justify-center gap-2 rounded-full px-4 py-2.5 text-sm font-semibold"
            >
              <.icon name="hero-pencil-square" class="size-5" /> Edit item
            </.link>
          </div>

          <div
            :if={detail_feedback?(@care_feedback, @modal.item_detail.item_card.item.id)}
            id="item-detail-feedback"
            class="garden-feedback-pill mt-4 inline-flex items-center gap-2 rounded-full px-3 py-1.5 text-xs font-semibold uppercase tracking-[0.18em] motion-safe:animate-pulse"
          >
            <.icon name="hero-check-circle" class="size-4" />
            {@care_feedback.label}
          </div>
        </div>

        <div class="grid gap-3 sm:grid-cols-2">
          <.detail_card
            id="item-detail-due"
            label="Due"
            value={due_value(@modal.item_detail.item_card)}
          />
          <.detail_card
            :if={show_interval_card?(@modal.item_detail.item_card.item)}
            id="item-detail-interval"
            label="Watering rhythm"
            value={interval_copy(@modal.item_detail.item_card.item.watering_interval_days)}
          />
          <.detail_card
            id="item-detail-last-watered"
            label="Last watered"
            value={format_optional_date(@modal.item_detail.item_card.item.last_watered_on)}
          />
          <.detail_card
            id="item-detail-last-checked"
            label="Last checked"
            value={format_optional_date(@modal.item_detail.item_card.item.last_checked_on)}
          />
        </div>

        <div
          id="item-detail-history"
          class="garden-panel-soft rounded-[1.4rem] p-4"
        >
          <div class="flex items-center justify-between gap-3">
            <div>
              <h3 class="garden-heading mt-1 px-2 text-lg font-semibold tracking-tight">
                Latest care events
              </h3>
            </div>
            <span class="garden-text-faint text-xs font-medium uppercase tracking-[0.18em]">
              {length(@modal.item_detail.recent_events)} events
            </span>
          </div>

          <div
            :if={@modal.item_detail.recent_events == []}
            id="item-detail-history-empty"
            class="mt-4"
          >
            <p class="garden-text-muted text-sm">
              No care history
            </p>
          </div>

          <div :if={@modal.item_detail.recent_events != []} class="mt-4 space-y-3">
            <article
              :for={event <- @modal.item_detail.recent_events}
              id={"item-detail-history-event-#{event.id}"}
              class="garden-history-item rounded-[1.2rem] px-4 py-3"
            >
              <div class="flex flex-col gap-2 sm:flex-row sm:items-start sm:justify-between">
                <div class="min-w-0 space-y-2">
                  <p class="garden-text-primary text-sm font-semibold leading-tight">
                    {history_event_label(event)}
                  </p>
                  <p class="garden-text-faint text-[0.7rem] font-semibold uppercase tracking-[0.18em] sm:hidden">
                    {format_date(event.occurred_on)}
                  </p>
                  <p class="garden-text-muted text-sm leading-tight">
                    {history_member_name(event)}
                  </p>
                  <p
                    :if={history_event_note(event)}
                    class="garden-text-muted text-sm leading-6 break-words"
                  >
                    {history_event_note(event)}
                  </p>
                </div>
                <p class="garden-text-faint hidden shrink-0 text-xs font-semibold uppercase tracking-[0.18em] sm:block">
                  {format_date(event.occurred_on)}
                </p>
              </div>
            </article>
          </div>
        </div>
      </div>
    </ModalComponents.modal_frame>
    """
  end

  attr :id, :string, required: true
  attr :label, :string, required: true
  attr :value, :string, required: true

  defp detail_card(assigns) do
    ~H"""
    <article
      id={@id}
      class="garden-detail-card rounded-[1.35rem] px-4 py-3"
    >
      <p class="garden-text-faint text-xs font-semibold uppercase tracking-[0.2em]">{@label}</p>
      <p class="garden-text-primary text-base font-semibold">{@value}</p>
    </article>
    """
  end

  @spec format_date(Date.t()) :: String.t()
  defp format_date(%Date{} = date), do: Calendar.strftime(date, "%A, %B %-d, %Y")

  @spec format_optional_date(nil | Date.t()) :: String.t()
  defp format_optional_date(nil), do: "None"
  defp format_optional_date(%Date{} = date), do: format_date(date)

  @spec due_value(CareItemCard.t()) :: String.t()
  defp due_value(%CareItemCard{status: :no_schedule}), do: "No schedule"
  defp due_value(%CareItemCard{effective_due_on: %Date{} = due_on}), do: format_date(due_on)

  @spec interval_copy(pos_integer()) :: String.t()
  defp interval_copy(1), do: "Every day"
  defp interval_copy(days), do: "Every #{days} days"

  @spec show_interval_card?(CareItem.t()) :: boolean()
  defp show_interval_card?(%CareItem{watering_interval_days: interval})
       when is_integer(interval) and interval > 0,
       do: true

  defp show_interval_card?(%CareItem{}), do: false

  @spec section_name(%{optional(Section.id()) => Section.t()}, Section.id() | nil) :: String.t()
  defp section_name(section_lookup, section_id) when is_integer(section_id) do
    case Map.get(section_lookup, section_id) do
      %Section{name: name} -> name
      nil -> "Unknown section"
    end
  end

  defp section_name(_, _), do: "Unknown section"

  @spec history_member_name(CareEvent.t()) :: String.t()
  defp history_member_name(%CareEvent{actor_member: %Member{name: name}}), do: name
  defp history_member_name(%CareEvent{}), do: "Unknown member"

  @spec history_event_label(CareEvent.t()) :: String.t()
  defp history_event_label(%CareEvent{event_type: :watered}), do: "Watered"
  defp history_event_label(%CareEvent{event_type: :soil_checked}), do: "Soil checked"
  defp history_event_label(%CareEvent{event_type: :schedule_changed}), do: "Schedule changed"

  defp history_event_label(%CareEvent{event_type: :manual_needs_watering}),
    do: "Marked needs water"

  @spec history_event_note(CareEvent.t()) :: nil | String.t()
  defp history_event_note(%CareEvent{event_type: :soil_checked, postpone_days: days})
       when is_integer(days) do
    "+#{days} days"
  end

  defp history_event_note(%CareEvent{
         event_type: :manual_needs_watering,
         manual_target_on: %Date{} = target_on
       }) do
    "For #{Calendar.strftime(target_on, "%b %-d")}"
  end

  defp history_event_note(%CareEvent{
         event_type: :schedule_changed,
         previous_due_on: %Date{},
         resulting_due_on: nil
       }) do
    "Cleared schedule"
  end

  defp history_event_note(%CareEvent{
         event_type: :schedule_changed,
         previous_due_on: nil,
         resulting_due_on: %Date{} = resulting_due_on
       }) do
    "Set next due date to #{Calendar.strftime(resulting_due_on, "%b %-d")}"
  end

  defp history_event_note(%CareEvent{
         event_type: :schedule_changed,
         previous_due_on: %Date{} = previous_due_on,
         resulting_due_on: %Date{} = resulting_due_on
       }) do
    "Moved due date from #{Calendar.strftime(previous_due_on, "%b %-d")} to #{Calendar.strftime(resulting_due_on, "%b %-d")}"
  end

  defp history_event_note(%CareEvent{}), do: nil

  @spec detail_feedback?(nil | CareFeedback.t(), CareItem.id()) :: boolean()
  defp detail_feedback?(nil, _), do: false
  defp detail_feedback?(%CareFeedback{item_id: item_id}, item_id), do: true
  defp detail_feedback?(_, _), do: false
end
