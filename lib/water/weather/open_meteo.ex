defmodule Water.Weather.OpenMeteo do
  @behaviour Water.Weather.Fetcher

  alias Water.Weather.{Forecast, ForecastDay}

  @forecast_url "https://api.open-meteo.com/v1/forecast"

  @impl true
  @spec fetch_forecast(float(), float()) :: Water.Weather.result(Forecast.t())
  def fetch_forecast(latitude, longitude)
      when is_float(latitude) and is_float(longitude) do
    case Req.get(
           url: @forecast_url,
           params: [
             latitude: latitude,
             longitude: longitude,
             daily: "weather_code,temperature_2m_min,temperature_2m_max,precipitation_sum",
             forecast_days: 7,
             temperature_unit: "celsius",
             timezone: "auto"
           ]
         ) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        decode_forecast(body)

      {:ok, %Req.Response{}} ->
        {:error, :request_failed}

      {:error, _exception} ->
        {:error, :request_failed}
    end
  end

  @spec decode_forecast(map()) :: Water.Weather.result(Forecast.t())
  def decode_forecast(%{
        "daily" => %{
          "time" => dates,
          "weather_code" => weather_codes,
          "temperature_2m_min" => min_temperatures,
          "temperature_2m_max" => max_temperatures,
          "precipitation_sum" => precipitation_sums
        }
      })
      when is_list(dates) and is_list(weather_codes) and is_list(min_temperatures) and
             is_list(max_temperatures) and is_list(precipitation_sums) do
    with :ok <-
           matching_lengths([
             dates,
             weather_codes,
             min_temperatures,
             max_temperatures,
             precipitation_sums
           ]),
         {:ok, days} <-
           build_forecast_days(
             dates,
             weather_codes,
             min_temperatures,
             max_temperatures,
             precipitation_sums
           ) do
      {:ok, %Forecast{days: days}}
    else
      :error -> {:error, :invalid_response}
    end
  end

  def decode_forecast(_response), do: {:error, :invalid_response}

  @spec matching_lengths([list()]) :: :ok | :error
  # Open-Meteo returns daily values as parallel arrays;
  # if their lengths drift, reject the payload (don't silently zip the wrong values)
  defp matching_lengths(lists) do
    case lists |> Enum.map(&length/1) |> Enum.uniq() do
      # all lists have the same length, good to go
      [_] -> :ok
      # more then one length, reject the payload
      _ -> :error
    end
  end

  @spec build_forecast_days([String.t()], list(), list(), list(), list()) ::
          {:ok, [ForecastDay.t()]} | :error
  defp build_forecast_days(
         dates,
         weather_codes,
         min_temperatures,
         max_temperatures,
         precipitation_sums
       ) do
    days =
      dates
      |> Enum.with_index()
      |> Enum.map(fn {date_string, index} ->
        build_forecast_day(
          date_string,
          Enum.at(weather_codes, index),
          Enum.at(min_temperatures, index),
          Enum.at(max_temperatures, index),
          Enum.at(precipitation_sums, index)
        )
      end)

    if Enum.all?(days, &match?({:ok, %ForecastDay{}}, &1)) do
      {:ok, Enum.map(days, fn {:ok, day} -> day end)}
    else
      :error
    end
  end

  @spec build_forecast_day(String.t(), term(), term(), term(), term()) ::
          {:ok, ForecastDay.t()} | :error
  defp build_forecast_day(
         date_string,
         weather_code,
         min_temperature,
         max_temperature,
         precipitation_sum
       )
       when is_binary(date_string) and is_number(weather_code) and is_number(min_temperature) and
              is_number(max_temperature) and is_number(precipitation_sum) do
    case Date.from_iso8601(date_string) do
      {:ok, date} ->
        {:ok,
         %ForecastDay{
           date: date,
           weather_code: round(weather_code),
           min_temperature_c: round(min_temperature),
           max_temperature_c: round(max_temperature),
           precipitation_sum_mm: precipitation_sum
         }}

      {:error, _reason} ->
        :error
    end
  end

  defp build_forecast_day(_, _, _, _, _),
    do: :error
end
