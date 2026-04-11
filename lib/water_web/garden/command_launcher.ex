defmodule WaterWeb.Garden.CommandLauncher do
  @moduledoc false

  alias Water.Garden.Section
  alias WaterWeb.Garden.CommandLauncher.Commands
  alias WaterWeb.Garden.CommandLauncher.Entry
  alias WaterWeb.Garden.CommandLauncher.Items
  alias WaterWeb.Garden.CommandLauncher.Ranking
  alias WaterWeb.Garden.State.CommandLauncher, as: LauncherState
  alias WaterWeb.Garden.State.ToolMode

  @type context() :: %{
          household: Water.Households.Household.t(),
          sections: [Section.t()],
          section_lookup: %{optional(Section.id()) => Section.t()},
          today: Date.t(),
          tool_mode: ToolMode.t(),
          current_filter: Water.Garden.Board.filter()
        }

  @spec new() :: LauncherState.t()
  @doc """
  Creates the closed empty launcher
  """
  def new do
    %LauncherState{
      open?: false,
      query: "",
      selected_index: nil,
      results: []
    }
  end

  @spec open(context()) :: LauncherState.t()
  @doc """
  Resets and rebuilds the results from the given context
  """
  def open(context) do
    refresh(%{new() | open?: true}, context)
  end

  @spec close() :: LauncherState.t()
  @doc """
  Closes launcher and clears query, selection, and results
  """
  def close, do: new()

  @spec toggle(LauncherState.t(), context()) :: LauncherState.t()
  def toggle(%LauncherState{open?: true}, _context), do: close()
  def toggle(%LauncherState{} = _state, context), do: open(context)

  @spec update_query(LauncherState.t(), String.t(), context()) :: LauncherState.t()
  @doc """
  Updates the query and recomputes the results
  """
  def update_query(%LauncherState{} = state, query, context) when is_binary(query) do
    state
    |> Map.put(:query, query)
    |> refresh(context)
  end

  @spec move_selection(LauncherState.t(), integer()) :: LauncherState.t()
  @doc """
  Note that the selection is index-based, not id-based.
  Non-selectable entries are going to be skipped.
  """
  def move_selection(%LauncherState{} = state, delta) when delta in [-1, 1] do
    selectable_indexes =
      state.results
      |> Enum.with_index()
      |> Enum.filter(fn {entry, _} -> entry.selectable? end)
      |> Enum.map(&elem(&1, 1))

    case selectable_indexes do
      [] ->
        %{state | selected_index: nil}

      indexes ->
        current_index =
          case Enum.find_index(indexes, &(&1 == state.selected_index)) do
            nil -> 0
            value -> value
          end

        next_index = Integer.mod(current_index + delta, length(indexes))
        %{state | selected_index: Enum.at(indexes, next_index)}
    end
  end

  @spec selected_entry(LauncherState.t()) :: nil | Entry.t()
  @doc """
  Maps the selected index to the actual entry.
  """
  def selected_entry(%LauncherState{selected_index: nil}), do: nil

  def selected_entry(%LauncherState{results: results, selected_index: selected_index}) do
    Enum.at(results, selected_index)
  end

  @spec entry_by_id(LauncherState.t(), String.t()) :: nil | Entry.t()
  def entry_by_id(%LauncherState{results: results}, entry_id) do
    Enum.find(results, &(&1.id == entry_id))
  end

  @spec no_op_action?(Entry.action(), ToolMode.t() | nil, Water.Garden.Board.filter() | nil) ::
          boolean()
  @doc """
  If the tool is already selected or the filter is applied – it's a noop.
  We can just close the launcher without doing redundant work.
  """
  def no_op_action?({:set_tool_mode, tool_mode}, tool_mode, _filter), do: true
  def no_op_action?({:set_filter, filter}, _tool_mode, filter), do: true
  def no_op_action?(_, _, _), do: false

  @spec command_results(LauncherState.t()) :: [Entry.t()]
  def command_results(%LauncherState{results: results}) do
    Enum.filter(results, &(&1.group == :commands))
  end

  @spec item_results(LauncherState.t()) :: [Entry.t()]
  def item_results(%LauncherState{results: results}) do
    Enum.filter(results, &(&1.group == :items))
  end

  @spec refresh(LauncherState.t(), context()) :: LauncherState.t()
  defp refresh(%LauncherState{} = state, context) do
    results =
      context
      |> build_results(state.query)
      |> Ranking.cap_group(:commands, 5)
      |> Ranking.cap_group(:items, 5)

    %{state | results: results, selected_index: first_selectable_index(results)}
  end

  @spec build_results(context(), String.t()) :: [Entry.t()]
  defp build_results(context, query) do
    query = Ranking.normalize_text(query)

    if query == "" do
      Commands.default_results(context)
    else
      Commands.search_results(context, query) ++ Items.search_results(context, query)
    end
  end

  @spec first_selectable_index([Entry.t()]) :: nil | non_neg_integer()
  defp first_selectable_index(results) do
    Enum.find_index(results, & &1.selectable?)
  end
end
