defmodule Water.WeatherTest do
  use ExUnit.Case, async: false

  alias Water.Weather
  alias Water.Weather.Cache
  alias Water.Weather.Forecast
  alias Water.Weather.ForecastDay
  alias Water.Weather.OpenMeteo

  setup do
    previous_ttl = Application.get_env(:water, :weather_cache_ttl_ms)
    previous_stub = Application.get_env(:water, Water.TestWeatherFetcher)

    Cache.clear()

    on_exit(fn ->
      Cache.clear()
      restore_env(:weather_cache_ttl_ms, previous_ttl)
      restore_env(Water.TestWeatherFetcher, previous_stub)
    end)

    :ok
  end

  describe "OpenMeteo.decode_forecast/1" do
    test "maps an Open-Meteo forecast payload into daily forecast days" do
      assert {:ok, %Forecast{} = forecast} =
               OpenMeteo.decode_forecast(%{
                 "daily" => %{
                   "time" => ["2026-03-29", "2026-03-30", "2026-03-31"],
                   "weather_code" => [2, 3, 61],
                   "temperature_2m_min" => [6.1, 8.0, 9.2],
                   "temperature_2m_max" => [15.4, 16.3, 17.1],
                   "precipitation_sum" => [0.0, 0.0, 5.5]
                 }
               })

      assert Enum.map(forecast.days, & &1.date) == [
               ~D[2026-03-29],
               ~D[2026-03-30],
               ~D[2026-03-31]
             ]

      assert Enum.map(forecast.days, & &1.weather_code) == [2, 3, 61]
      assert Enum.map(forecast.days, & &1.min_temperature_c) == [6, 8, 9]
      assert Enum.map(forecast.days, & &1.max_temperature_c) == [15, 16, 17]
      assert Enum.map(forecast.days, & &1.precipitation_sum_mm) == [0.0, 0.0, 5.5]
    end

    test "rejects malformed forecast responses" do
      assert OpenMeteo.decode_forecast(%{"daily" => %{"time" => ["2026-03-29"]}}) ==
               {:error, :invalid_response}
    end
  end

  describe "fetch_forecast/2" do
    test "serves repeated nearby coordinate lookups from cache" do
      Application.put_env(
        :water,
        Water.TestWeatherFetcher,
        %{
          notify_pid: self(),
          forecast_response: {:ok, sample_forecast()}
        }
      )

      assert {:ok, %Forecast{} = forecast} = Weather.fetch_forecast(37.7741, -122.4194)
      assert {:ok, ^forecast} = Weather.fetch_forecast(37.7749, -122.4191)

      assert_received {:weather_fetch_forecast, 37.7741, -122.4194}
      refute_received {:weather_fetch_forecast, 37.7749, -122.4191}
    end

    test "falls back to stale cached forecast when refresh fails" do
      Application.put_env(:water, :weather_cache_ttl_ms, 0)

      Application.put_env(
        :water,
        Water.TestWeatherFetcher,
        %{
          notify_pid: self(),
          forecast_response: {:ok, sample_forecast()}
        }
      )

      assert {:ok, %Forecast{} = forecast} = Weather.fetch_forecast(48.85, 2.35)
      assert_received {:weather_fetch_forecast, 48.85, 2.35}

      Application.put_env(
        :water,
        Water.TestWeatherFetcher,
        %{
          notify_pid: self(),
          forecast_response: {:error, :request_failed}
        }
      )

      assert {:ok, ^forecast} = Weather.fetch_forecast(48.85, 2.35)
      assert_received {:weather_fetch_forecast, 48.85, 2.35}
    end
  end

  describe "forecast urls" do
    test "formats the temperature forecast website URL from coordinates" do
      assert Weather.temperature_forecast_url(37.7749, -122.4194) ==
               "https://www.windy.com/37.7749/-122.4194?temp,37.7749,-122.4194,8"
    end

    test "formats the rain overlay URL from coordinates" do
      assert Weather.rain_forecast_url(37.7749, -122.4194) ==
               "https://www.windy.com/37.7749/-122.4194?rain,37.7749,-122.4194,8"
    end
  end

  @spec sample_forecast() :: Forecast.t()
  defp sample_forecast do
    %Forecast{
      days: [
        %ForecastDay{
          date: ~D[2026-03-29],
          weather_code: 2,
          min_temperature_c: 6,
          max_temperature_c: 15,
          precipitation_sum_mm: 0.0
        },
        %ForecastDay{
          date: ~D[2026-03-30],
          weather_code: 3,
          min_temperature_c: 8,
          max_temperature_c: 16,
          precipitation_sum_mm: 0.0
        },
        %ForecastDay{
          date: ~D[2026-03-31],
          weather_code: 61,
          min_temperature_c: 9,
          max_temperature_c: 17,
          precipitation_sum_mm: 5.5
        }
      ]
    }
  end

  @spec restore_env(atom() | module(), term()) :: :ok
  defp restore_env(key, nil) do
    Application.delete_env(:water, key)
    :ok
  end

  defp restore_env(key, value) do
    Application.put_env(:water, key, value)
    :ok
  end
end
