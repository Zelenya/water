defmodule Water.Weather.Cache do
  @moduledoc """
  In-memory cache for weather lookups used by the board HUD.

  This cache is process-local and intentionally simple. Weather is helpful
  context, not core business state, so the app favors fast reads and graceful
  degradation over durable storage or cross-node coordination.
  """
  use GenServer

  alias Water.Weather.Forecast

  @table __MODULE__

  @type key() :: {float(), float()}
  @type data() :: Forecast.t()
  @type entry() :: {key(), data(), integer()}

  @spec child_spec(term()) :: Supervisor.child_spec()
  def child_spec(_arg) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [[]]}
    }
  end

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, Keyword.put(opts, :name, __MODULE__))
  end

  @spec get(key(), non_neg_integer()) :: {:fresh | :stale, data()} | :miss
  def get(key, ttl_ms) when is_tuple(key) and is_integer(ttl_ms) and ttl_ms >= 0 do
    case :ets.lookup(@table, key) do
      [{^key, weather_data, inserted_at_ms}] ->
        case weather_data do
          %Forecast{} ->
            freshness(inserted_at_ms, ttl_ms, weather_data)

          _other ->
            :miss
        end

      [] ->
        :miss
    end
  end

  @spec put(key(), data()) :: :ok
  def put(key, %Forecast{} = forecast) when is_tuple(key) do
    true = :ets.insert(@table, {key, forecast, now_ms()})
    :ok
  end

  @doc false
  @spec clear() :: :ok
  def clear do
    :ets.delete_all_objects(@table)
    :ok
  end

  @impl true
  def init(:ok) do
    _table =
      :ets.new(@table, [
        :named_table,
        :public,
        :set,
        read_concurrency: true,
        write_concurrency: true
      ])

    {:ok, %{}}
  end

  @spec stale?(integer(), non_neg_integer()) :: boolean()
  defp stale?(inserted_at_ms, ttl_ms) do
    now_ms() - inserted_at_ms >= ttl_ms
  end

  @spec freshness(integer(), non_neg_integer(), data()) :: {:fresh | :stale, data()}
  defp freshness(inserted_at_ms, ttl_ms, weather_data) do
    # `Water.Weather` can decide whether to serve stale data or attempt a
    # refresh; the cache only reports the age classification.
    if stale?(inserted_at_ms, ttl_ms) do
      {:stale, weather_data}
    else
      {:fresh, weather_data}
    end
  end

  @spec now_ms() :: integer()
  defp now_ms do
    System.monotonic_time(:millisecond)
  end
end
