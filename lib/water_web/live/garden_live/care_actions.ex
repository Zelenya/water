defmodule WaterWeb.GardenLive.CareActions do
  alias Water.Garden.CareItemCard
  alias WaterWeb.Garden.State.CareAction
  alias WaterWeb.GardenLive.CareActions.{Forms, Surface, Workflow}

  @spec handle_item_interaction(Phoenix.LiveView.Socket.t(), CareItemCard.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  defdelegate handle_item_interaction(socket, item_card), to: Workflow

  @spec execute_water_action(Phoenix.LiveView.Socket.t(), CareItemCard.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  defdelegate execute_water_action(socket, item_card), to: Workflow

  @spec execute_clear_schedule_action(Phoenix.LiveView.Socket.t(), CareItemCard.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  defdelegate execute_clear_schedule_action(socket, item_card), to: Workflow

  @spec execute_schedule_action(
          Phoenix.LiveView.Socket.t(),
          :usual_interval | {:days, pos_integer()}
        ) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  defdelegate execute_schedule_action(socket, postpone_days), to: Workflow

  @spec execute_schedule_preset(Phoenix.LiveView.Socket.t(), Date.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  defdelegate execute_schedule_preset(socket, target_on), to: Workflow

  @spec open_care_action(Phoenix.LiveView.Socket.t(), CareAction.kind(), CareItemCard.t()) ::
          Phoenix.LiveView.Socket.t()
  defdelegate open_care_action(socket, kind, item_card), to: Surface

  @spec update_schedule_action(Phoenix.LiveView.Socket.t(), (CareAction.t() -> CareAction.t())) ::
          Phoenix.LiveView.Socket.t()
  defdelegate update_schedule_action(socket, updater), to: Surface

  @spec schedule_form(CareItemCard.t(), Date.t(), map()) :: Phoenix.HTML.Form.t()
  defdelegate schedule_form(item_card, today, params \\ %{}), to: Forms

  @spec parse_schedule_days(nil | String.t()) :: :error | {:ok, pos_integer()}
  defdelegate parse_schedule_days(raw_value), to: Forms, as: :parse_postpone_days

  @spec schedule_postpone_days(Phoenix.LiveView.Socket.t(), nil | String.t()) ::
          :error | {:same_due_on, Date.t()} | {:ok, {:days, pos_integer()}}
  def schedule_postpone_days(socket, raw_target_on) do
    Forms.schedule_postpone_days(socket.assigns.care_action, raw_target_on, socket.assigns.today)
  end

  @spec parse_target_on(nil | String.t()) :: :error | {:ok, Date.t()}
  defdelegate parse_target_on(raw_value), to: Forms

  @spec put_care_action_error(Phoenix.LiveView.Socket.t(), String.t()) ::
          Phoenix.LiveView.Socket.t()
  defdelegate put_care_action_error(socket, message), to: Surface

  @spec clear_care_action(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  defdelegate clear_care_action(socket), to: Surface

  @spec clear_care_surface(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  defdelegate clear_care_surface(socket), to: Surface
end
