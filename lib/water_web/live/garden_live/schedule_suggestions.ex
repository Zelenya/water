defmodule WaterWeb.GardenLive.ScheduleSuggestions do
  import Phoenix.Component, only: [assign: 3]
  import Phoenix.LiveView, only: [put_flash: 3]

  alias Water.Garden
  alias Water.Garden.{CareItem, CareItemCard}
  alias Water.Households.Member
  alias WaterWeb.Garden.State.ScheduleSuggestion
  alias WaterWeb.GardenLive.Modals

  @spec maybe_open_after_watering(Phoenix.LiveView.Socket.t(), CareItem.t(), Date.t()) ::
          Phoenix.LiveView.Socket.t()
  @doc """
  Check if there are any schedule suggestions for that (updated) item.
  If so, open the schedule suggestion modal.
  """
  def maybe_open_after_watering(socket, %CareItem{} = updated_item, %Date{} = occurred_on) do
    case Garden.suggest_after_watering(updated_item, occurred_on) do
      %Garden.ScheduleSuggestion{} = suggestion ->
        item_card =
          Garden.get_item_card!(
            socket.assigns.household,
            suggestion.care_item_id,
            socket.assigns.today
          )

        assign(socket, :schedule_suggestion, %ScheduleSuggestion{
          item_card: item_card,
          suggestion: suggestion
        })

      nil ->
        socket
    end
  end

  @spec dismiss(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  def dismiss(socket), do: assign(socket, :schedule_suggestion, nil)

  @spec accept(Phoenix.LiveView.Socket.t()) :: {:noreply, Phoenix.LiveView.Socket.t()}
  def accept(socket) do
    case {socket.assigns.schedule_suggestion, socket.assigns.active_member} do
      {%ScheduleSuggestion{item_card: %CareItemCard{item: %CareItem{} = item}} = suggestion,
       %Member{} = member} ->
        case Garden.apply_schedule_suggestion(item, member, suggestion.suggestion) do
          {:ok, updated_item} ->
            {:noreply,
             socket
             |> dismiss()
             |> refresh_board()
             |> Modals.refresh_item_detail(updated_item.id)
             |> put_flash(
               :info,
               "#{updated_item.name} now waters #{interval_copy(suggestion.suggestion.suggested_interval_days)}."
             )}

          {:error, :member_household_mismatch} ->
            {:noreply, put_flash(socket, :error, "The active member cannot update this item.")}

          {:error, :suggestion_item_mismatch} ->
            {:noreply,
             socket
             |> dismiss()
             |> put_flash(:error, "That suggested schedule no longer matches this item.")}

          {:error, %Ecto.Changeset{}} ->
            {:noreply, put_flash(socket, :error, "That suggested schedule could not be saved.")}
        end

      _other ->
        {:noreply, socket}
    end
  end

  @spec refresh_board(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  defp refresh_board(socket) do
    board =
      Garden.list_board(
        socket.assigns.household,
        socket.assigns.current_filter,
        socket.assigns.today
      )

    assign(socket, :board, board)
  end

  @spec interval_copy(pos_integer()) :: String.t()
  defp interval_copy(1), do: "every day"
  defp interval_copy(interval), do: "every #{interval} days"
end
