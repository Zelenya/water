defmodule WaterWeb.GardenWeatherLiveTest do
  use WaterWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import WaterWeb.GardenLiveTestHelpers

  alias Water.Weather.{Forecast, ForecastDay}

  setup do
    previous_stub_response = Application.get_env(:water, Water.TestWeatherFetcher)

    on_exit(fn ->
      restore_env(Water.TestWeatherFetcher, previous_stub_response)
    end)

    :ok
  end

  describe "top hud weather" do
    test "initial render shows the loading placeholder in the top hud", %{conn: conn} do
      _board = seed_board()

      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "#garden-weather-card-today", "Today")
      assert has_element?(view, "#garden-weather-card-today", "--°C/--°C")
      assert has_element?(view, "#garden-weather-card-tomorrow", "Tomorrow")
      assert has_element?(view, "#garden-weather-card-tomorrow", "--°C/--°C")
      assert has_element?(view, "#garden-weather-card-rain", "Rain")
      assert has_element?(view, "#garden-weather-card-rain", "Checking rain")
    end

    test "a successful location update shows forecast cards and forecast links",
         %{conn: conn} do
      _board = seed_board()
      rain_day = ~D[2026-03-30]

      Application.put_env(
        :water,
        Water.TestWeatherFetcher,
        %{
          forecast_response:
            {:ok,
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
                   min_temperature_c: 7,
                   max_temperature_c: 14,
                   precipitation_sum_mm: 0.0
                 },
                 %ForecastDay{
                   date: rain_day,
                   weather_code: 61,
                   min_temperature_c: 8,
                   max_temperature_c: 13,
                   precipitation_sum_mm: 4.2
                 }
               ]
             }}
        }
      )

      {:ok, view, _html} = live(conn, ~p"/")

      render_hook(view, "weather_location_ready", %{
        "latitude" => "37.7749",
        "longitude" => "-122.4194"
      })

      assert has_element?(view, "#garden-weather-card-today", "Today")
      assert has_element?(view, "#garden-weather-card-today", "6°C/15°C")
      assert has_element?(view, "#garden-weather-card-tomorrow", "Tomorrow")
      assert has_element?(view, "#garden-weather-card-tomorrow", "7°C/14°C")
      assert has_element?(view, "#garden-weather-card-rain", "Tomorrow")
      assert has_element?(view, "#garden-weather-card-rain", "Next rain")

      assert has_element?(
               view,
               "#garden-weather-card-today[href='https://www.windy.com/37.7749/-122.4194?temp,37.7749,-122.4194,8'][target='_blank']"
             )

      assert has_element?(
               view,
               "#garden-weather-card-tomorrow[href='https://www.windy.com/37.7749/-122.4194?temp,37.7749,-122.4194,8'][target='_blank']"
             )

      assert has_element?(
               view,
               "#garden-weather-card-rain[href='https://www.windy.com/37.7749/-122.4194?rain,37.7749,-122.4194,8'][target='_blank']"
             )
    end

    test "a denied location update shows the unavailable fallback", %{conn: conn} do
      _board = seed_board()

      {:ok, view, _html} = live(conn, ~p"/")

      render_hook(view, "weather_location_unavailable", %{"reason" => "denied"})

      assert has_element?(view, "#garden-weather-card-today", "No data")
      assert has_element?(view, "#garden-weather-card-tomorrow", "No data")
      assert has_element?(view, "#garden-weather-card-rain", "No data")
      refute has_element?(view, "#garden-weather-card-today[href]")
      refute has_element?(view, "#garden-weather-card-tomorrow[href]")
      refute has_element?(view, "#garden-weather-card-rain[href]")
    end
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
