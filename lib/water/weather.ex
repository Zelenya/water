defmodule Water.Weather do
  alias Water.Weather.{Cache, Forecast, OpenMeteo}

  @typedoc "Failures surfaced to the garden weather UI."
  @type fetch_error() :: :request_failed | :invalid_response
  @type result(value) :: {:ok, value} | {:error, fetch_error()}

  # used when redirecting to external forecast service (not the actual weather data)
  @forecast_site_base_url "https://www.windy.com"
  @forecast_site_zoom 8
  @rain_overlay "rain"
  @temperature_overlay "temp"

  @spec fetch_forecast(float(), float()) :: result(Forecast.t())
  def fetch_forecast(latitude, longitude)
      when is_float(latitude) and is_float(longitude) do
    cache_key = cache_key(latitude, longitude)

    case Cache.get(cache_key, cache_ttl_ms()) do
      {:fresh, %Forecast{} = forecast} ->
        {:ok, forecast}

      {:stale, %Forecast{} = forecast} ->
        refresh_stale_forecast(cache_key, latitude, longitude, forecast)

      :miss ->
        fetch_and_cache_forecast(cache_key, latitude, longitude)
    end
  end

  @spec fetch_and_cache_forecast(Cache.key(), float(), float()) :: result(Forecast.t())
  defp fetch_and_cache_forecast(cache_key, latitude, longitude) do
    case fetcher().fetch_forecast(latitude, longitude) do
      {:ok, %Forecast{} = forecast} ->
        :ok = Cache.put(cache_key, forecast)
        {:ok, forecast}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec refresh_stale_forecast(Cache.key(), float(), float(), Forecast.t()) ::
          result(Forecast.t())
  defp refresh_stale_forecast(cache_key, latitude, longitude, %Forecast{} = stale_forecast) do
    case fetch_and_cache_forecast(cache_key, latitude, longitude) do
      {:ok, %Forecast{} = forecast} -> {:ok, forecast}
      {:error, _reason} -> {:ok, stale_forecast}
    end
  end

  @spec fetcher() :: module()
  defp fetcher do
    Application.get_env(:water, :weather_fetcher, OpenMeteo)
  end

  @spec cache_ttl_ms() :: non_neg_integer()
  defp cache_ttl_ms do
    Application.get_env(:water, :weather_cache_ttl_ms, :timer.minutes(30))
  end

  @spec cache_key(float(), float()) :: Cache.key()
  defp cache_key(latitude, longitude) do
    # We intentionally bucket nearby coordinates together. We don't need high precision.
    {Float.round(latitude, 2), Float.round(longitude, 2)}
  end

  @spec temperature_forecast_url(float(), float()) :: String.t()
  def temperature_forecast_url(latitude, longitude)
      when is_float(latitude) and is_float(longitude),
      do: overlay_url(latitude, longitude, @temperature_overlay)

  @spec rain_forecast_url(float(), float()) :: String.t()
  def rain_forecast_url(latitude, longitude)
      when is_float(latitude) and is_float(longitude),
      do: overlay_url(latitude, longitude, @rain_overlay)

  @spec overlay_url(float(), float(), String.t()) :: String.t()
  defp overlay_url(latitude, longitude, overlay) do
    formatted_latitude = format_coordinate(latitude)
    formatted_longitude = format_coordinate(longitude)

    "#{@forecast_site_base_url}/#{formatted_latitude}/#{formatted_longitude}" <>
      "?#{overlay},#{formatted_latitude},#{formatted_longitude},#{@forecast_site_zoom}"
  end

  @spec format_coordinate(float()) :: String.t()
  defp format_coordinate(coordinate) do
    coordinate
    |> Float.round(4)
    |> :erlang.float_to_binary(decimals: 4)
  end
end
