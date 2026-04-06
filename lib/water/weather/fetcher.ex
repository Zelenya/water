defmodule Water.Weather.Fetcher do
  @moduledoc """
  Behaviour contract for weather forecast providers.

  `Water.Weather` owns the application-facing weather API. Fetcher modules only
  implement the provider-specific "given coordinates, return a forecast" part of
  that boundary.
  """

  alias Water.Weather.Forecast

  @callback fetch_forecast(float(), float()) :: Water.Weather.result(Forecast.t())
end
