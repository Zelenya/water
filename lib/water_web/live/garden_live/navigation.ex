defmodule WaterWeb.GardenLive.Navigation do
  @moduledoc """
  Deal with raw input/params (so the rest of the app can rely on normalized values).
  """
  use Phoenix.VerifiedRoutes,
    endpoint: WaterWeb.Endpoint,
    router: WaterWeb.Router,
    statics: WaterWeb.static_paths()

  alias Water.Garden.{Board, CareItem, CareItemCard}
  alias Water.Households.{Household, Member}
  alias WaterWeb.Garden.State.ToolMode

  @type interaction_kind() :: :soil_check | :schedule_watering

  @spec active_member_from_session!([Member.t()], integer() | String.t() | nil) :: Member.t()
  @doc """
  Returns the active member from the session, raising if not found.
  It takes the full list of household members and the raw member id from the session (which might be invalid).
  """
  def active_member_from_session!(members, raw_member_id) do
    case normalize_member_id(raw_member_id) do
      nil ->
        raise "active member missing from session"

      member_id ->
        case Enum.find(members, &(&1.id == member_id and &1.active)) do
          %Member{} = member -> member
          nil -> raise "active member missing from session"
        end
    end
  end

  @spec household_today(Household.t()) :: Date.t()
  def household_today(%Household{timezone: timezone}) do
    timezone
    |> DateTime.now!()
    |> DateTime.to_date()
  end

  @spec parse_filter(map()) :: Board.filter()
  def parse_filter(params) do
    case Map.get(params, "filter") do
      nil ->
        :all

      "today" ->
        :today

      "tomorrow" ->
        :tomorrow

      "overdue" ->
        :overdue

      "no_schedule" ->
        :no_schedule

      # Note: silently ignores unknown filter values instead of surfacing an error
      _other ->
        :all
    end
  end

  @spec filter_query_params(Board.filter()) :: map()
  # Inverse of parse_filter
  def filter_query_params(:all), do: %{}
  def filter_query_params(:today), do: %{"filter" => "today"}
  def filter_query_params(:tomorrow), do: %{"filter" => "tomorrow"}
  def filter_query_params(:overdue), do: %{"filter" => "overdue"}
  def filter_query_params(:no_schedule), do: %{"filter" => "no_schedule"}

  @spec parse_tool_mode(String.t()) :: ToolMode.t()
  def parse_tool_mode("browse"), do: :browse
  def parse_tool_mode("water"), do: :water
  def parse_tool_mode("soil_check"), do: :soil_check
  def parse_tool_mode("manual_needs_watering"), do: :manual_needs_watering
  def parse_tool_mode(_other), do: :browse

  @spec parse_interaction_kind(String.t()) :: nil | interaction_kind()
  def parse_interaction_kind("soil_check"), do: :soil_check
  def parse_interaction_kind("schedule_watering"), do: :schedule_watering
  def parse_interaction_kind(_other), do: nil

  @spec board_path(map()) :: String.t()
  # :all becomes / instead of /?
  def board_path(params) when map_size(params) == 0, do: ~p"/"
  def board_path(params), do: ~p"/?#{params}"

  @spec item_show_path(CareItem.id(), map()) :: String.t()
  def item_show_path(item_id, params) when map_size(params) == 0, do: ~p"/items/#{item_id}"
  def item_show_path(item_id, params), do: ~p"/items/#{item_id}?#{params}"

  @spec edit_item_path(CareItem.id(), map()) :: String.t()
  def edit_item_path(item_id, params) when map_size(params) == 0, do: ~p"/items/#{item_id}/edit"
  def edit_item_path(item_id, params), do: ~p"/items/#{item_id}/edit?#{params}"

  @spec item_id!(map()) :: integer()
  @doc """
  Used for route params, throws because an invalid input means a programmer-error
  """
  def item_id!(params) do
    case Integer.parse(Map.fetch!(params, "id")) do
      {item_id, ""} when item_id > 0 -> item_id
      _other -> raise ArgumentError, "invalid item id"
    end
  end

  @spec parse_item_id(nil | String.t()) :: nil | integer()
  @doc """
  Used for form params, returns nil for invalid input
  """
  def parse_item_id(nil), do: nil

  def parse_item_id(raw_item_id) do
    case Integer.parse(raw_item_id) do
      {item_id, ""} when item_id > 0 -> item_id
      _other -> nil
    end
  end

  @spec board_item_card(Board.t(), nil | integer()) :: nil | CareItemCard.t()
  @doc """
  Locates clicked item inside the already-built board
  """
  def board_item_card(_board, nil), do: nil

  def board_item_card(%Board{} = board, item_id) do
    Enum.find(board.needs_care_items, &(&1.item.id == item_id)) ||
      Enum.find_value(board.sections, fn section_card ->
        Enum.find(section_card.items, &(&1.item.id == item_id))
      end)
  end

  @spec normalize_member_id(integer() | String.t() | nil) :: nil | integer()
  defp normalize_member_id(member_id) when is_integer(member_id) and member_id > 0, do: member_id

  defp normalize_member_id(member_id) when is_binary(member_id) do
    case Integer.parse(member_id) do
      {parsed_member_id, ""} when parsed_member_id > 0 -> parsed_member_id
      _ -> nil
    end
  end

  defp normalize_member_id(_other), do: nil
end
