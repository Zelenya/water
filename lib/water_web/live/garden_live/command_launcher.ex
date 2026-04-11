defmodule WaterWeb.GardenLive.CommandLauncher do
  @moduledoc false

  import Phoenix.Component, only: [assign: 3]
  import Phoenix.LiveView, only: [push_patch: 2]

  alias WaterWeb.Garden.CommandLauncher, as: LauncherRegistry
  alias WaterWeb.Garden.State.ToolMode
  alias WaterWeb.GardenLive.{CareActions, Navigation}

  @spec toggle(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  def toggle(socket) do
    assign(
      socket,
      :command_launcher,
      LauncherRegistry.toggle(socket.assigns.command_launcher, launcher_context(socket))
    )
  end

  @spec close(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  def close(socket) do
    assign(socket, :command_launcher, LauncherRegistry.close())
  end

  @spec switch_tool_mode(Phoenix.LiveView.Socket.t(), ToolMode.t()) :: Phoenix.LiveView.Socket.t()
  def switch_tool_mode(socket, tool_mode) do
    socket
    |> assign(:tool_mode, tool_mode)
    |> CareActions.clear_care_surface()
  end

  @spec update_query(Phoenix.LiveView.Socket.t(), String.t()) :: Phoenix.LiveView.Socket.t()
  def update_query(socket, query) do
    assign(
      socket,
      :command_launcher,
      LauncherRegistry.update_query(
        socket.assigns.command_launcher,
        query,
        launcher_context(socket)
      )
    )
  end

  @spec move_selection(Phoenix.LiveView.Socket.t(), integer()) :: Phoenix.LiveView.Socket.t()
  def move_selection(socket, delta) do
    assign(
      socket,
      :command_launcher,
      LauncherRegistry.move_selection(socket.assigns.command_launcher, delta)
    )
  end

  @spec selected_entry(Phoenix.LiveView.Socket.t()) :: nil | LauncherRegistry.Entry.t()
  def selected_entry(socket) do
    LauncherRegistry.selected_entry(socket.assigns.command_launcher)
  end

  @spec entry_by_id(Phoenix.LiveView.Socket.t(), String.t()) :: nil | LauncherRegistry.Entry.t()
  def entry_by_id(socket, entry_id) do
    LauncherRegistry.entry_by_id(socket.assigns.command_launcher, entry_id)
  end

  @spec execute_entry(Phoenix.LiveView.Socket.t(), LauncherRegistry.Entry.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def execute_entry(socket, entry) do
    cond do
      !entry.selectable? ->
        {:noreply, socket}

      LauncherRegistry.no_op_action?(
        entry.action,
        socket.assigns.tool_mode,
        socket.assigns.current_filter
      ) ->
        {:noreply, close(socket)}

      true ->
        {:noreply, execute_action(socket, entry.action)}
    end
  end

  @spec sync(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  def sync(socket) do
    %{command_launcher: command_launcher} = socket.assigns

    launcher =
      if command_launcher.open? do
        LauncherRegistry.update_query(
          command_launcher,
          command_launcher.query,
          launcher_context(socket)
        )
      else
        command_launcher
      end

    assign(socket, :command_launcher, launcher)
  end

  @spec execute_action(Phoenix.LiveView.Socket.t(), LauncherRegistry.Entry.action()) ::
          Phoenix.LiveView.Socket.t()
  defp execute_action(socket, {:set_tool_mode, tool_mode}) do
    socket
    |> close()
    |> switch_tool_mode(tool_mode)
  end

  defp execute_action(socket, {:set_filter, filter}) do
    socket
    |> close()
    |> push_patch(to: Navigation.board_path(Navigation.filter_query_params(filter)))
  end

  defp execute_action(socket, :new_item) do
    socket
    |> close()
    |> push_patch(to: Navigation.item_new_path(socket.assigns.filter_query_params))
  end

  defp execute_action(socket, {:show_item, item_id}) do
    socket
    |> close()
    |> push_patch(to: Navigation.item_show_path(item_id, socket.assigns.filter_query_params))
  end

  @spec launcher_context(Phoenix.LiveView.Socket.t()) :: LauncherRegistry.context()
  defp launcher_context(socket) do
    %{
      household: socket.assigns.household,
      sections: socket.assigns.sections,
      section_lookup: socket.assigns.section_lookup,
      today: socket.assigns.today,
      tool_mode: socket.assigns.tool_mode,
      current_filter: socket.assigns.current_filter
    }
  end
end
