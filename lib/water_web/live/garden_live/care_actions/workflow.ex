defmodule WaterWeb.GardenLive.CareActions.Workflow do
  import Phoenix.LiveView, only: [put_flash: 3, push_patch: 2]
  import Phoenix.Component, only: [assign: 3]

  alias Water.Garden
  alias Water.Garden.{CareItem, CareItemCard}
  alias Water.Households.Member
  alias WaterWeb.Garden.State.CareAction
  alias WaterWeb.GardenLive.{Modals, Navigation}
  alias WaterWeb.GardenLive.CareActions.Surface

  @spec handle_item_interaction(Phoenix.LiveView.Socket.t(), CareItemCard.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  @doc """
  Answers what should "clicking" on an item should do.
  Note that we have some direct actions and some that open a modal.
  """
  def handle_item_interaction(socket, %CareItemCard{} = item_card) do
    case socket.assigns.tool_mode do
      :browse ->
        {:noreply,
         socket
         |> Surface.clear_care_surface()
         |> push_patch(
           to: Navigation.item_show_path(item_card.item.id, socket.assigns.filter_query_params)
         )}

      :water ->
        execute_water_action(socket, item_card)

      :soil_check ->
        {:noreply, Surface.open_care_action(socket, :soil_check, item_card)}

      :manual_needs_watering ->
        perform_manual_action(socket, item_card, socket.assigns.today)
    end
  end

  @spec execute_water_action(Phoenix.LiveView.Socket.t(), CareItemCard.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def execute_water_action(socket, %CareItemCard{} = item_card) do
    with_active_member(socket, fn active_member ->
      case Garden.water_item(item_card.item, active_member, socket.assigns.today) do
        {:ok, _} ->
          {:noreply, apply_successful_care_action(socket, item_card.item.id, "Watered")}

        {:error, :no_state_change} ->
          {:noreply,
           socket
           |> Surface.clear_care_action()
           |> Surface.assign_care_feedback(item_card.item.id, "Already watered today")}

        {:error, :stale} ->
          {:noreply,
           socket
           |> refresh_board()
           |> Modals.refresh_item_detail(item_card.item.id)
           |> Surface.clear_care_action()
           |> put_flash(:error, "That item changed before your action landed. Try again.")}

        {:error, :member_household_mismatch} ->
          {:noreply, put_flash(socket, :error, "The active member cannot update this item.")}

        {:error, %Ecto.Changeset{}} ->
          {:noreply, put_flash(socket, :error, "That watering action could not be saved.")}
      end
    end)
  end

  @spec execute_water_all(Phoenix.LiveView.Socket.t()) :: {:noreply, Phoenix.LiveView.Socket.t()}
  def execute_water_all(socket) do
    with_active_member(socket, fn active_member ->
      {watered_count, had_error} =
        socket.assigns.household
        |> Garden.list_household_items()
        |> Enum.reduce({0, false}, fn item, {watered_count, had_error} ->
          case Garden.water_item(item, active_member, socket.assigns.today) do
            {:ok, _} ->
              {watered_count + 1, had_error}

            {:error, :no_state_change} ->
              {watered_count, had_error}

            {:error, _reason} ->
              {watered_count, true}
          end
        end)

      socket =
        if watered_count > 0 do
          socket
          |> refresh_board()
          |> put_flash(:info, "Watered #{watered_count} household items.")
        else
          put_flash(socket, :info, "No household items needed watering.")
        end

      socket =
        if had_error do
          put_flash(socket, :error, "Some items could not be watered.")
        else
          socket
        end

      {:noreply, socket}
    end)
  end

  @spec execute_clear_schedule_action(Phoenix.LiveView.Socket.t(), CareItemCard.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def execute_clear_schedule_action(socket, %CareItemCard{} = item_card) do
    with_active_member(socket, fn active_member ->
      case Garden.clear_schedule_item(item_card.item, active_member, socket.assigns.today) do
        {:ok, _} ->
          {:noreply, apply_successful_care_action(socket, item_card.item.id, "No schedule")}

        {:error, :no_state_change} ->
          {:noreply,
           socket
           |> Surface.clear_care_action()
           |> Surface.assign_care_feedback(item_card.item.id, "Already no schedule")}

        {:error, :stale} ->
          {:noreply,
           socket
           |> refresh_board()
           |> Modals.refresh_item_detail(item_card.item.id)
           |> Surface.clear_care_action()
           |> put_flash(:error, "That item changed before your schedule was cleared. Try again.")}

        {:error, :member_household_mismatch} ->
          {:noreply, put_flash(socket, :error, "The active member cannot update this item.")}

        {:error, %Ecto.Changeset{}} ->
          {:noreply, put_flash(socket, :error, "That schedule change could not be saved.")}
      end
    end)
  end

  @spec execute_schedule_action(
          Phoenix.LiveView.Socket.t(),
          :usual_interval | {:days, pos_integer()}
        ) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def execute_schedule_action(socket, postpone_days) do
    case socket.assigns.care_action do
      %CareAction{kind: kind, item_card: %CareItemCard{} = item_card}
      when kind in [:soil_check, :schedule_watering] ->
        with_active_member(socket, fn active_member ->
          case Garden.soil_check_item(
                 item_card.item,
                 active_member,
                 postpone_days,
                 socket.assigns.today
               ) do
            {:ok, _} ->
              label =
                case postpone_days do
                  :usual_interval -> "+#{item_card.item.watering_interval_days}d"
                  {:days, days} -> "+#{days}d"
                end

              {:noreply,
               apply_successful_care_action(
                 socket,
                 item_card.item.id,
                 label
               )}

            {:error, :invalid_postpone_days} ->
              {:noreply,
               Surface.put_care_action_error(socket, "Enter a positive number of days.")}

            {:error, :stale} ->
              {:noreply,
               socket
               |> refresh_board()
               |> Modals.refresh_item_detail(item_card.item.id)
               |> Surface.clear_care_action()
               |> put_flash(
                 :error,
                 "That item changed before your schedule was saved. Try again."
               )}

            {:error, :member_household_mismatch} ->
              {:noreply, put_flash(socket, :error, "The active member cannot update this item.")}

            {:error, :no_state_change} ->
              {:noreply, Surface.clear_care_action(socket)}

            {:error, %Ecto.Changeset{}} ->
              {:noreply, put_flash(socket, :error, "That watering schedule could not be saved.")}
          end
        end)

      _other ->
        {:noreply, socket}
    end
  end

  @spec execute_schedule_preset(Phoenix.LiveView.Socket.t(), Date.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  # Special case for scheduling a watering item (for moving due date to today/tomorrow)
  def execute_schedule_preset(socket, %Date{} = target_on) do
    case socket.assigns.care_action do
      %CareAction{kind: :schedule_watering, item_card: %CareItemCard{} = item_card} ->
        perform_manual_action(socket, item_card, target_on)

      _other ->
        {:noreply, socket}
    end
  end

  @spec perform_manual_action(
          Phoenix.LiveView.Socket.t(),
          CareItemCard.t(),
          Date.t()
        ) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  # Sets explicit due watering date
  defp perform_manual_action(socket, %CareItemCard{} = item_card, %Date{} = target_on) do
    with_active_member(socket, fn active_member ->
      case Garden.mark_item_needs_watering(
             item_card.item,
             active_member,
             target_on,
             socket.assigns.today
           ) do
        {:ok, _} ->
          label =
            if Date.compare(target_on, socket.assigns.today) == :eq do
              "Needs Watering Today"
            else
              "Needs Watering on #{Calendar.strftime(target_on, "%b %-d")}"
            end

          {:noreply, apply_successful_care_action(socket, item_card.item.id, label)}

        {:error, :invalid_manual_target} ->
          {:noreply,
           Surface.put_care_action_error(socket, "Choose a valid date on or after today.")}

        {:error, :stale} ->
          {:noreply,
           socket
           |> refresh_board()
           |> Modals.refresh_item_detail(item_card.item.id)
           |> Surface.clear_care_action()
           |> put_flash(
             :error,
             "That item changed before your reminder was saved. Try again."
           )}

        {:error, :member_household_mismatch} ->
          {:noreply, put_flash(socket, :error, "The active member cannot update this item.")}

        {:error, :no_state_change} ->
          {:noreply, Surface.clear_care_action(socket)}

        {:error, %Ecto.Changeset{}} ->
          {:noreply, put_flash(socket, :error, "That reminder could not be saved.")}
      end
    end)
  end

  @spec apply_successful_care_action(
          Phoenix.LiveView.Socket.t(),
          CareItem.id(),
          String.t()
        ) :: Phoenix.LiveView.Socket.t()
  # Update UI in the specific order to avoid flickering and ensure consistency
  defp apply_successful_care_action(socket, item_id, label) do
    socket
    |> refresh_board()
    |> Modals.refresh_item_detail(item_id)
    |> Surface.clear_care_action()
    |> Surface.assign_care_feedback(item_id, label)
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

  @spec with_active_member(Phoenix.LiveView.Socket.t(), (Member.t() ->
                                                           {:noreply, Phoenix.LiveView.Socket.t()})) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  # Safety net: all care actions need an active member
  defp with_active_member(socket, fun) do
    case socket.assigns.active_member do
      %Member{} = active_member ->
        fun.(active_member)

      nil ->
        {:noreply, put_flash(socket, :error, "An active member is required for care actions.")}
    end
  end
end
