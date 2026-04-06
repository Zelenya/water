defmodule Water.TestWeatherFetcher do
  @moduledoc false

  @behaviour Water.Weather.Fetcher

  alias Water.Weather.Forecast

  @impl true
  @spec fetch_forecast(float(), float()) ::
          {:ok, Forecast.t()} | {:error, Water.Weather.fetch_error()}
  def fetch_forecast(latitude, longitude) do
    config = Application.get_env(:water, __MODULE__, %{})

    if pid = Map.get(config, :notify_pid) do
      send(pid, {:weather_fetch_forecast, latitude, longitude})
    end

    Map.get(config, :forecast_response, {:error, :request_failed})
  end
end
