defmodule WaterWeb.Garden.Shared.SurfaceClasses do
  @moduledoc false

  @surface_base "border border-[var(--garden-border)] text-[var(--garden-text-primary)]"
  @panel_soft "#{@surface_base} bg-[var(--garden-surface-soft)] shadow-[var(--garden-shadow-md)]"
  @panel_card "#{@surface_base} bg-[var(--garden-surface-card)] shadow-[var(--garden-shadow-sm)]"
  @modal_surface "#{@surface_base} overflow-hidden bg-[var(--garden-surface-modal)] shadow-[var(--garden-shadow-modal)]"
  @history_surface "#{@surface_base} bg-[var(--garden-surface-history)]"
  @empty_state "#{@surface_base} bg-[var(--garden-surface-elevated)] shadow-[var(--garden-shadow-md)]"

  @spec panel_soft() :: String.t()
  def panel_soft, do: @panel_soft

  @spec panel_card() :: String.t()
  def panel_card, do: @panel_card

  @spec modal_overlay() :: String.t()
  def modal_overlay, do: "bg-[var(--garden-overlay)]"

  @spec modal_surface() :: String.t()
  def modal_surface, do: @modal_surface

  @spec detail_card() :: String.t()
  def detail_card, do: @history_surface

  @spec history_item() :: String.t()
  def history_item, do: @history_surface

  @spec empty_state() :: String.t()
  def empty_state, do: @empty_state
end
