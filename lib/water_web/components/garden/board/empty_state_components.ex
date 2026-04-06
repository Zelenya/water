defmodule WaterWeb.Garden.Board.EmptyStateComponents do
  use WaterWeb, :html

  alias Water.Garden.Board

  attr :id, :string, required: true
  attr :title, :string, required: true
  attr :body, :string, required: true
  attr :action_text, :string, default: nil

  def empty_state(assigns) do
    ~H"""
    <section
      id={@id}
      class="garden-empty-state rounded-[1.8rem] border-dashed px-6 py-8 text-center"
    >
      <div class="mx-auto max-w-xl space-y-3">
        <p class="garden-kicker text-xs font-semibold uppercase tracking-[0.2em]">Garden board</p>
        <h2 class="garden-heading text-2xl font-semibold tracking-tight">{@title}</h2>
        <p class="garden-text-muted text-sm leading-6">{@body}</p>
        <p :if={@action_text} class="garden-text-primary text-sm font-medium">{@action_text}</p>
      </div>
    </section>
    """
  end

  @spec empty_filter_body(Board.filter()) :: String.t()
  def empty_filter_body(:today) do
    "There is nothing due today"
  end

  def empty_filter_body(:tomorrow) do
    "Nothing is scheduled for tomorrow yet"
  end

  def empty_filter_body(:overdue) do
    "Great news: nothing is overdue!"
  end

  def empty_filter_body(:no_schedule) do
    "Everything has an active due date"
  end
end
