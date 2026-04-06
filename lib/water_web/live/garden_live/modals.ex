defmodule WaterWeb.GardenLive.Modals do
  import Phoenix.Component, only: [assign: 3, to_form: 2]
  import Phoenix.LiveView, only: [put_flash: 3, push_patch: 2]

  alias Water.Garden
  alias Water.Garden.{Board, CareItem, CareItemCard, CareItemDetail}
  alias WaterWeb.Garden.State.Modal
  alias WaterWeb.GardenLive.Navigation

  @item_form_as :item

  @spec apply_live_action(Phoenix.LiveView.Socket.t(), atom(), map(), Board.filter()) ::
          Phoenix.LiveView.Socket.t()
  def apply_live_action(socket, :index, _params, _filter) do
    socket
    |> assign(:page_title, "Garden")
    |> assign(:modal, nil)
  end

  def apply_live_action(socket, :new, _params, filter) do
    close_path = modal_close_path(filter)

    if Enum.empty?(socket.assigns.sections) do
      socket
      |> assign(:page_title, "Add Item")
      |> assign(
        :modal,
        %Modal{
          kind: :new_unavailable,
          title: "Add Item",
          close_path: close_path
        }
      )
    else
      changeset = Garden.new_item_changeset(socket.assigns.household, %{})

      socket
      |> assign(:page_title, "Add Item")
      |> assign(
        :modal,
        %Modal{
          kind: :new_form,
          title: "Add Item",
          close_path: close_path,
          schedule_mode: :recurring,
          form: to_form(changeset, as: @item_form_as)
        }
      )
    end
  end

  def apply_live_action(socket, :show, params, filter) do
    item_detail =
      Garden.get_item_detail!(
        socket.assigns.household,
        Navigation.item_id!(params),
        socket.assigns.today
      )

    socket
    |> assign(:page_title, item_detail.item_card.item.name)
    |> assign(
      :modal,
      %Modal{
        kind: :show_detail,
        title: item_detail.item_card.item.name,
        close_path: modal_close_path(filter),
        item_detail: item_detail
      }
    )
  end

  def apply_live_action(socket, :edit, params, filter) do
    item_card =
      Garden.get_item_card!(
        socket.assigns.household,
        Navigation.item_id!(params),
        socket.assigns.today
      )

    socket
    |> assign(:page_title, "Edit Item")
    |> assign(
      :modal,
      %Modal{
        kind: :edit_form,
        title: "Edit Item",
        close_path: modal_close_path(filter),
        schedule_mode: schedule_mode_from_item(item_card.item),
        form: to_form(Garden.change_item(item_card.item, %{}), as: @item_form_as),
        item_card: item_card
      }
    )
  end

  @spec validate_item(Phoenix.LiveView.Socket.t(), map()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def validate_item(socket, item_params) do
    schedule_mode = schedule_mode_from_params(item_params, socket.assigns.modal)

    changeset =
      case socket.assigns.modal do
        %Modal{kind: :new_form} ->
          Garden.new_item_changeset(socket.assigns.household, item_params)

        %Modal{kind: :edit_form, item_card: %CareItemCard{} = item_card} ->
          Garden.change_item(item_card.item, item_params)

        _other ->
          nil
      end

    {:noreply, maybe_assign_form(socket, changeset, schedule_mode)}
  end

  @spec save_item(Phoenix.LiveView.Socket.t(), map()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def save_item(socket, item_params) do
    case socket.assigns.modal do
      %Modal{kind: :new_form} ->
        case Garden.create_item(socket.assigns.household, item_params) do
          {:ok, %CareItem{name: name}} ->
            {:noreply,
             socket
             |> assign(:modal, nil)
             |> put_flash(:info, "#{name} added to the board.")
             |> push_patch(to: Navigation.board_path(socket.assigns.filter_query_params))}

          {:error, changeset} ->
            {:noreply,
             assign_form(
               socket,
               changeset,
               schedule_mode_from_params(item_params, socket.assigns.modal)
             )}
        end

      %Modal{kind: :edit_form, item_card: %CareItemCard{} = item_card} ->
        case Garden.update_item(item_card.item, socket.assigns.active_member, item_params) do
          {:ok, %CareItem{name: name}} ->
            {:noreply,
             socket
             |> assign(:modal, nil)
             |> put_flash(:info, "#{name} updated.")
             |> push_patch(to: Navigation.board_path(socket.assigns.filter_query_params))}

          {:error, :member_household_mismatch} ->
            {:noreply, put_flash(socket, :error, "The active member cannot update this item.")}

          {:error, changeset} ->
            {:noreply,
             assign_form(
               socket,
               changeset,
               schedule_mode_from_params(item_params, socket.assigns.modal)
             )}
        end

      _other ->
        {:noreply, socket}
    end
  end

  @spec detail_item_card(Phoenix.LiveView.Socket.t()) :: nil | CareItemCard.t()
  def detail_item_card(socket) do
    case socket.assigns.modal do
      %Modal{
        kind: :show_detail,
        item_detail: %CareItemDetail{item_card: %CareItemCard{} = item_card}
      } ->
        item_card

      _other ->
        nil
    end
  end

  @spec refresh_item_detail(Phoenix.LiveView.Socket.t(), CareItem.id()) ::
          Phoenix.LiveView.Socket.t()
  def refresh_item_detail(socket, item_id) do
    case socket.assigns.modal do
      %Modal{
        kind: :show_detail,
        item_detail: %CareItemDetail{item_card: %CareItemCard{item: %CareItem{id: ^item_id}}}
      } = modal ->
        assign(
          socket,
          :modal,
          %{
            modal
            | item_detail:
                Garden.get_item_detail!(socket.assigns.household, item_id, socket.assigns.today)
          }
        )

      _other ->
        socket
    end
  end

  @spec modal_close_path(Board.filter()) :: String.t()
  def modal_close_path(filter) do
    Navigation.board_path(Navigation.filter_query_params(filter))
  end

  @spec assign_form(
          Phoenix.LiveView.Socket.t(),
          Ecto.Changeset.t(),
          nil | :recurring | :no_schedule
        ) ::
          Phoenix.LiveView.Socket.t()
  defp assign_form(socket, changeset, schedule_mode) do
    case socket.assigns.modal do
      %Modal{} = modal ->
        assign(socket, :modal, %{
          modal
          | form: to_form(changeset, as: @item_form_as),
            schedule_mode: schedule_mode || modal.schedule_mode
        })

      nil ->
        socket
    end
  end

  @spec maybe_assign_form(
          Phoenix.LiveView.Socket.t(),
          nil | Ecto.Changeset.t(),
          nil | :recurring | :no_schedule
        ) ::
          Phoenix.LiveView.Socket.t()
  defp maybe_assign_form(socket, nil, _schedule_mode), do: socket

  defp maybe_assign_form(socket, changeset, schedule_mode) do
    assign_form(socket, %{changeset | action: :validate}, schedule_mode)
  end

  @spec schedule_mode_from_item(CareItem.t()) :: :recurring | :no_schedule
  defp schedule_mode_from_item(%CareItem{watering_interval_days: interval})
       when is_integer(interval) and interval > 0,
       do: :recurring

  defp schedule_mode_from_item(%CareItem{}), do: :no_schedule

  @spec schedule_mode_from_params(map(), nil | Modal.t()) :: nil | :recurring | :no_schedule
  defp schedule_mode_from_params(item_params, modal) do
    case Map.get(item_params, "schedule_mode") || Map.get(item_params, :schedule_mode) do
      "recurring" -> :recurring
      :recurring -> :recurring
      "no_schedule" -> :no_schedule
      :no_schedule -> :no_schedule
      _other -> modal && modal.schedule_mode
    end
  end
end
