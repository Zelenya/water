defmodule WaterWeb.Garden.Shared.VisualComponents do
  use WaterWeb, :html

  alias Water.Garden.{CareItem, Schedule}

  attr :id, :string, default: nil
  attr :status, :atom, required: true
  attr :quiet, :boolean, default: false

  def status_badge(assigns) do
    ~H"""
    <span id={@id} class={status_badge_classes(@status, @quiet)}>
      {status_label(@status)}
    </span>
    """
  end

  attr :name, :string, required: true
  attr :class, :any, default: nil

  def garden_icon(assigns) do
    ~H"""
    <span
      data-lucide-icon={@name}
      class={["garden-lucide-icon inline-flex items-center justify-center", @class]}
      aria-hidden="true"
    />
    """
  end

  attr :id, :string, default: nil
  attr :label, :string, required: true
  attr :value, :integer, required: true
  attr :tone, :string, required: true

  def summary_pill(assigns) do
    ~H"""
    <span id={@id} class={summary_pill_classes(@tone)}>
      {@label} {@value}
    </span>
    """
  end

  @spec item_icon_name(CareItem.kind()) :: String.t()
  def item_icon_name(:plant), do: "sprout"
  def item_icon_name(:area), do: "trees"
  def item_icon_name(:bed), do: "bed-single"

  @spec status_badge_classes(Schedule.status(), boolean()) :: [String.t()]
  defp status_badge_classes(status, quiet?) do
    [
      "garden-status-badge inline-flex items-center rounded-full border font-semibold uppercase",
      quiet? && "garden-status-badge-quiet px-2 py-0.5 text-[0.68rem] tracking-[0.14em]",
      !quiet? && "px-2.5 py-1 text-xs tracking-[0.18em]",
      status_badge_tone_class(status)
    ]
  end

  @spec status_badge_tone_class(Schedule.status()) :: String.t()
  defp status_badge_tone_class(:overdue), do: "garden-status-badge-rose"
  defp status_badge_tone_class(:due_today), do: "garden-status-badge-orange"
  defp status_badge_tone_class(:manually_flagged), do: "garden-status-badge-amber"
  defp status_badge_tone_class(:soon), do: "garden-status-badge-amber"
  defp status_badge_tone_class(:normal), do: "garden-status-badge-emerald"
  defp status_badge_tone_class(:no_schedule), do: "garden-status-badge-sky"

  @spec status_label(Schedule.status()) :: String.t()
  defp status_label(:overdue), do: "Overdue"
  defp status_label(:due_today), do: "Today"
  # [TODO] Remove Flagged?
  defp status_label(:manually_flagged), do: "Flagged"
  defp status_label(:soon), do: "Soon"
  defp status_label(:normal), do: "Normal"
  defp status_label(:no_schedule), do: "No schedule"

  @spec summary_pill_classes(String.t()) :: [String.t()]
  defp summary_pill_classes(tone) do
    ["garden-summary-pill", summary_pill_tone_class(tone)]
  end

  defp summary_pill_tone_class("orange"), do: "garden-summary-pill-orange"
  defp summary_pill_tone_class("sky"), do: "garden-summary-pill-sky"
  defp summary_pill_tone_class("amber"), do: "garden-summary-pill-amber"
  defp summary_pill_tone_class("rose"), do: "garden-summary-pill-rose"
end
