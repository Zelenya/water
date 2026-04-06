defmodule Water.Weather.ForecastDay do
  @moduledoc """
  Single normalized day in the weather forecast.
  """
  @enforce_keys [
    :date,
    :weather_code,
    :min_temperature_c,
    :max_temperature_c,
    :precipitation_sum_mm
  ]
  defstruct [:date, :weather_code, :min_temperature_c, :max_temperature_c, :precipitation_sum_mm]

  @type t() :: %__MODULE__{
          date: Date.t(),
          weather_code: integer(),
          min_temperature_c: integer(),
          max_temperature_c: integer(),
          precipitation_sum_mm: number()
        }

  @spec rainy?(t()) :: boolean()
  @doc """
  We use simple precipitation-sum based threshold to check for rainy days.
  """
  def rainy?(%__MODULE__{precipitation_sum_mm: precipitation_sum_mm}),
    do: precipitation_sum_mm > 0
end
