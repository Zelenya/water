defmodule WaterWeb.GardenLive.CareActions.Surface do
  @moduledoc """
  Handles care action and feedback. State reducer for care actions.
  """

  import Phoenix.Component, only: [assign: 3]

  alias Water.Garden.CareItemCard
  alias WaterWeb.Garden.State.{CareAction, CareFeedback}
  alias WaterWeb.GardenLive.CareActions.Forms

  @spec open_care_action(Phoenix.LiveView.Socket.t(), CareAction.kind(), CareItemCard.t()) ::
          Phoenix.LiveView.Socket.t()
  @doc """
  Starts a fresh care-action interaction for the given item
  """
  def open_care_action(socket, kind, %CareItemCard{} = item_card)
      when kind in [:soil_check, :schedule_watering] do
    socket
    |> assign(
      :care_action,
      %CareAction{
        kind: kind,
        item_card: item_card,
        mode: :picker,
        form: Forms.schedule_form(item_card, socket.assigns.today)
      }
    )
    |> assign(:care_feedback, nil)
  end

  @spec update_schedule_action(Phoenix.LiveView.Socket.t(), (CareAction.t() -> CareAction.t())) ::
          Phoenix.LiveView.Socket.t()
  def update_schedule_action(socket, updater) do
    update_care_action(socket, [:soil_check, :schedule_watering], updater)
  end

  @spec put_care_action_error(Phoenix.LiveView.Socket.t(), String.t()) ::
          Phoenix.LiveView.Socket.t()
  def put_care_action_error(socket, message) do
    case socket.assigns.care_action do
      %CareAction{} = action -> assign(socket, :care_action, %{action | error: message})
      nil -> socket
    end
  end

  @spec clear_care_action(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  @doc """
  Closes the active care action modal without clearing feedback. Closes current action.
  """
  def clear_care_action(socket), do: assign(socket, :care_action, nil)

  @spec clear_care_surface(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  @doc """
  Clears both the care action modal and feedback. Resets the whole care layer/state.
  """
  def clear_care_surface(socket) do
    socket
    |> assign(:care_action, nil)
    |> assign(:care_feedback, nil)
  end

  @spec assign_care_feedback(
          Phoenix.LiveView.Socket.t(),
          integer(),
          String.t()
        ) :: Phoenix.LiveView.Socket.t()
  def assign_care_feedback(socket, item_id, label) do
    assign(socket, :care_feedback, %CareFeedback{item_id: item_id, label: label})
  end

  @spec update_care_action(
          Phoenix.LiveView.Socket.t(),
          CareAction.kind()
          | [CareAction.kind()],
          (CareAction.t() -> CareAction.t())
        ) :: Phoenix.LiveView.Socket.t()
  defp update_care_action(socket, kind, updater) do
    case socket.assigns.care_action do
      %CareAction{kind: action_kind} = action ->
        if action_kind in List.wrap(kind) do
          assign(socket, :care_action, updater.(action))
        else
          socket
        end

      _other ->
        socket
    end
  end
end
