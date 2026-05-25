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

  @spec item_type_chip_classes(String.t() | [String.t()]) :: [String.t()]
  def item_type_chip_classes(extra_classes) do
    [
      "garden-item-type-chip inline-flex items-center justify-center",
      extra_classes
    ]
  end

  attr :id, :string, default: nil
  attr :label, :string, required: true
  attr :value, :integer, required: true
  attr :tone, :string, required: true
  attr :compact, :boolean, default: false

  def summary_pill(assigns) do
    ~H"""
    <span
      id={@id}
      class={summary_pill_classes(@tone, @compact)}
      title={"#{@label} #{@value}"}
      aria-label={"#{@label} #{@value}"}
      tabindex={if(@compact, do: "0", else: false)}
    >
      <span class="garden-summary-pill-label">{@label}</span>
      <span class="garden-summary-pill-value">{@value}</span>
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
      quiet? && "px-2 py-0.5 text-[0.68rem] tracking-[0.14em] opacity-[0.92]",
      !quiet? && "px-2.5 py-1 text-xs tracking-[0.18em]",
      status_badge_tone_class(status)
    ]
  end

  @spec status_badge_tone_class(Schedule.status()) :: String.t()
  defp status_badge_tone_class(:overdue), do: tone_classes("rose")
  defp status_badge_tone_class(:due_today), do: tone_classes("orange")
  defp status_badge_tone_class(:manually_flagged), do: tone_classes("amber")
  defp status_badge_tone_class(:soon), do: tone_classes("amber")
  defp status_badge_tone_class(:normal), do: tone_classes("emerald")
  defp status_badge_tone_class(:no_schedule), do: tone_classes("sky")

  @spec status_label(Schedule.status()) :: String.t()
  defp status_label(:overdue), do: "Overdue"
  defp status_label(:due_today), do: "Today"
  # [TODO] Remove Flagged?
  defp status_label(:manually_flagged), do: "Flagged"
  defp status_label(:soon), do: "Soon"
  defp status_label(:normal), do: "Normal"
  defp status_label(:no_schedule), do: "No schedule"

  @spec summary_pill_classes(String.t(), boolean()) :: [String.t()]
  defp summary_pill_classes(tone, true) do
    [
      "garden-summary-pill garden-summary-pill-compact inline-flex min-w-12 items-center justify-center overflow-hidden rounded-full border px-3 py-1 text-[0.65rem] font-medium uppercase leading-none tracking-[0.12em]",
      summary_pill_tone_class(tone)
    ]
  end

  defp summary_pill_classes(tone, false) do
    [
      "garden-summary-pill inline-flex min-w-[4.25rem] items-center justify-center gap-1 rounded-full border px-2.5 py-1 text-[0.65rem] font-medium uppercase leading-none tracking-[0.12em]",
      summary_pill_tone_class(tone)
    ]
  end

  defp summary_pill_tone_class("orange"), do: tone_classes("orange")
  defp summary_pill_tone_class("sky"), do: tone_classes("sky")
  defp summary_pill_tone_class("amber"), do: tone_classes("amber")
  defp summary_pill_tone_class("rose"), do: tone_classes("rose")

  @spec tone_classes(String.t()) :: String.t()
  defp tone_classes("amber"),
    do:
      "border-[var(--garden-status-amber-border)] bg-[var(--garden-status-amber-bg)] text-[var(--garden-status-amber-text)]"

  defp tone_classes("emerald"),
    do:
      "border-[var(--garden-status-emerald-border)] bg-[var(--garden-status-emerald-bg)] text-[var(--garden-status-emerald-text)]"

  defp tone_classes("orange"),
    do:
      "border-[var(--garden-status-orange-border)] bg-[var(--garden-status-orange-bg)] text-[var(--garden-status-orange-text)]"

  defp tone_classes("rose"),
    do:
      "border-[var(--garden-status-rose-border)] bg-[var(--garden-status-rose-bg)] text-[var(--garden-status-rose-text)]"

  defp tone_classes("sky"),
    do:
      "border-[var(--garden-status-sky-border)] bg-[var(--garden-status-sky-bg)] text-[var(--garden-status-sky-text)]"
end
