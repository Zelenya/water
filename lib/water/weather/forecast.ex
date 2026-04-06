defmodule Water.Weather.Forecast do
  @moduledoc """
  The UI only needs a few derived views, this struct exposes the specific access patterns.
  """
  @enforce_keys [:days]
  defstruct [:days]

  alias Water.Weather.ForecastDay

  @type t() :: %__MODULE__{
          days: [ForecastDay.t()]
        }

  @spec today_day(t()) :: ForecastDay.t() | nil
  def today_day(%__MODULE__{days: days}), do: Enum.at(days, 0)

  @spec tomorrow_day(t()) :: ForecastDay.t() | nil
  def tomorrow_day(%__MODULE__{days: days}), do: Enum.at(days, 1)

  @spec next_rain_day(t()) :: ForecastDay.t() | nil
  def next_rain_day(%__MODULE__{days: days}), do: Enum.find(days, &ForecastDay.rainy?/1)
end
