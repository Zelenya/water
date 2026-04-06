defmodule WaterWeb.Garden.Board.HudComponents do
  use WaterWeb, :html

  alias Water.Weather.{Forecast, ForecastDay}
  alias WaterWeb.Garden.Shared.VisualComponents

  attr :today, :any, required: true
  attr :weather_forecast_state, :any, default: :loading
  attr :temperature_forecast_url, :string, default: nil
  attr :rain_forecast_url, :string, default: nil

  @doc """
  The top of the board. Date on the left, simple weather cards on the right.

  The hidden geolocation hook is mounted here because the weather summary is
  the only part of the page that depends on browser coordinates. Keeping the
  hook local to this section avoids implying that the rest of the board depends
  on client geolocation to function.
  """
  def hud_section(assigns) do
    ~H"""
    <section
      id="garden-top-hud"
      class="garden-panel-hero overflow-hidden rounded-[2rem]"
    >
      <div class="px-6 py-5 sm:px-8">
        <div id="garden-weather-hook" phx-hook="GardenWeatherLocation" class="hidden" />
        <div class="flex flex-col gap-4 xl:flex-row xl:items-end xl:justify-between">
          <div class="min-w-0 space-y-1.5">
            <p class="garden-kicker text-xs font-semibold uppercase tracking-[0.2em]">
              Today
            </p>

            <p
              id="garden-top-hud-date"
              class="garden-heading text-2xl font-semibold tracking-tight sm:text-3xl"
            >
              {formatted_today(@today)}
            </p>
          </div>

          <div
            id="garden-weather-cards"
            class="grid flex-none grid-cols-3 gap-2 sm:gap-3 xl:min-w-[26rem]"
          >
            <.weather_card
              id="garden-weather-card-today"
              top_label="Today"
              icon_name={today_card_icon_name(@weather_forecast_state)}
              bottom_text={today_card_bottom_text(@weather_forecast_state)}
              tone={today_card_tone(@weather_forecast_state)}
              href={@temperature_forecast_url}
            />
            <.weather_card
              id="garden-weather-card-tomorrow"
              top_label="Tomorrow"
              icon_name={tomorrow_card_icon_name(@weather_forecast_state)}
              bottom_text={tomorrow_card_bottom_text(@weather_forecast_state)}
              tone={tomorrow_card_tone(@weather_forecast_state)}
              href={@temperature_forecast_url}
            />
            <.weather_card
              id="garden-weather-card-rain"
              top_label={rain_card_top_label(@weather_forecast_state)}
              icon_name={rain_card_icon_name(@weather_forecast_state)}
              icon_glyph={rain_card_icon_glyph(@weather_forecast_state)}
              bottom_text={rain_card_bottom_text(@weather_forecast_state)}
              tone={rain_card_tone(@weather_forecast_state)}
              href={@rain_forecast_url}
            />
          </div>
        </div>
      </div>
    </section>
    """
  end

  attr :id, :string, required: true
  attr :top_label, :string, required: true
  attr :icon_name, :string, default: nil
  attr :icon_glyph, :string, default: nil
  attr :bottom_text, :string, required: true
  attr :tone, :string, required: true
  attr :href, :string, default: nil

  # Decides whether to render as a link based on the `href` attribute.
  defp weather_card(assigns) do
    ~H"""
    <%= if @href do %>
      <.link
        id={@id}
        href={@href}
        target="_blank"
        rel="noopener noreferrer"
        class={weather_card_classes(@tone, true)}
      >
        <.weather_card_content
          top_label={@top_label}
          icon_name={@icon_name}
          icon_glyph={@icon_glyph}
          bottom_text={@bottom_text}
          tone={@tone}
        />
      </.link>
    <% else %>
      <article id={@id} class={weather_card_classes(@tone, false)}>
        <.weather_card_content
          top_label={@top_label}
          icon_name={@icon_name}
          icon_glyph={@icon_glyph}
          bottom_text={@bottom_text}
          tone={@tone}
        />
      </article>
    <% end %>
    """
  end

  attr :top_label, :string, required: true
  attr :icon_name, :string, default: nil
  attr :icon_glyph, :string, default: nil
  attr :bottom_text, :string, required: true
  attr :tone, :string, required: true

  # All weather cards are the same: top label, icon, bottom text.
  defp weather_card_content(assigns) do
    ~H"""
    <div class="flex min-h-[5.75rem] flex-col items-center justify-between text-center sm:min-h-[6.75rem]">
      <p class="text-[0.65rem] font-semibold tracking-[0.14em] sm:text-xs sm:tracking-[0.16em]">
        {@top_label}
      </p>

      <div class="flex min-h-8 items-center justify-center sm:min-h-10">
        <%= if @icon_name do %>
          <VisualComponents.garden_icon
            name={@icon_name}
            class={["size-7 sm:size-10", weather_icon_class(@tone)]}
          />
        <% else %>
          <span class={[
            "text-[1.8rem] font-semibold leading-none tracking-tight opacity-80 sm:text-[2.25rem]",
            weather_glyph_class(@tone, @icon_glyph)
          ]}>
            {@icon_glyph}
          </span>
        <% end %>
      </div>

      <p class="text-[0.72rem] font-semibold leading-tight tracking-tight sm:text-sm">
        {@bottom_text}
      </p>
    </div>
    """
  end

  @spec formatted_today(Date.t()) :: String.t()
  defp formatted_today(%Date{} = today), do: Calendar.strftime(today, "%A, %B %-d, %Y")

  @spec weather_card_classes(String.t(), boolean()) :: [String.t()]
  defp weather_card_classes(tone, linked?) do
    [
      "garden-count-card rounded-[1.35rem] px-2.5 py-2 shadow-sm no-underline sm:rounded-[1.5rem] sm:px-4 sm:py-2.5",
      weather_card_tone_class(tone),
      linked? && "transition hover:-translate-y-0.5 hover:shadow-md"
    ]
  end

  defp weather_card_tone_class("orange"), do: "garden-count-card-orange"
  defp weather_card_tone_class("sky"), do: "garden-count-card-sky"
  defp weather_card_tone_class("amber"), do: "garden-count-card-amber"
  defp weather_card_tone_class("rose"), do: "garden-count-card-rose"

  @spec today_card_icon_name(:loading | {:ok, Forecast.t()} | {:error, term()}) :: String.t()
  defp today_card_icon_name(:loading), do: "sun"

  defp today_card_icon_name({:ok, %Forecast{} = forecast}) do
    # Missing provider data should still render a stable optimistic card instead
    # of collapsing the layout or changing the card's identity.
    forecast
    |> Forecast.today_day()
    |> weather_code_icon_name("sun")
  end

  defp today_card_icon_name({:error, _reason}), do: "sun"

  @spec today_card_tone(:loading | {:ok, Forecast.t()} | {:error, term()}) :: String.t()
  defp today_card_tone(weather_state),
    do: weather_tone_for_icon_name(today_card_icon_name(weather_state))

  @spec today_card_bottom_text(:loading | {:ok, Forecast.t()} | {:error, term()}) :: String.t()
  defp today_card_bottom_text(:loading), do: "--°C/--°C"

  defp today_card_bottom_text({:ok, %Forecast{} = forecast}) do
    case Forecast.today_day(forecast) do
      %ForecastDay{} = forecast_day -> temperature_range_text(forecast_day)
      nil -> "No data"
    end
  end

  defp today_card_bottom_text({:error, _reason}), do: "No data"

  @spec tomorrow_card_icon_name(:loading | {:ok, Forecast.t()} | {:error, term()}) :: String.t()
  defp tomorrow_card_icon_name(:loading), do: "cloud-sun"

  defp tomorrow_card_icon_name({:ok, %Forecast{} = forecast}) do
    forecast
    |> Forecast.tomorrow_day()
    |> weather_code_icon_name("cloud-sun")
  end

  defp tomorrow_card_icon_name({:error, _reason}), do: "cloud-sun"

  @spec tomorrow_card_tone(:loading | {:ok, Forecast.t()} | {:error, term()}) :: String.t()
  defp tomorrow_card_tone(weather_state),
    do: weather_tone_for_icon_name(tomorrow_card_icon_name(weather_state))

  @spec tomorrow_card_bottom_text(:loading | {:ok, Forecast.t()} | {:error, term()}) :: String.t()
  defp tomorrow_card_bottom_text(:loading), do: "--°C/--°C"

  defp tomorrow_card_bottom_text({:ok, %Forecast{} = forecast}) do
    case Forecast.tomorrow_day(forecast) do
      %ForecastDay{} = forecast_day -> temperature_range_text(forecast_day)
      nil -> "No data"
    end
  end

  defp tomorrow_card_bottom_text({:error, _reason}), do: "No data"

  @spec rain_card_top_label(:loading | {:ok, Forecast.t()} | {:error, term()}) :: String.t()
  defp rain_card_top_label(:loading), do: "Rain"

  defp rain_card_top_label({:ok, %Forecast{} = forecast}) do
    # The rain card answers "when is the next rain event?" rather than showing
    # a fixed day slot, so its label becomes the weekday of the next rainy day.
    case Forecast.next_rain_day(forecast) do
      %ForecastDay{date: date} ->
        rain_day_label(forecast, date)

      nil ->
        "Next 7 days"
    end
  end

  defp rain_card_top_label({:error, _reason}), do: "Rain"

  @spec rain_card_icon_name(:loading | {:ok, Forecast.t()} | {:error, term()}) :: String.t() | nil
  defp rain_card_icon_name(:loading), do: "cloud-rain"

  defp rain_card_icon_name({:ok, %Forecast{} = forecast}) do
    case Forecast.next_rain_day(forecast) do
      %ForecastDay{} -> "cloud-rain"
      nil -> nil
    end
  end

  defp rain_card_icon_name({:error, _reason}), do: "cloud-rain"

  @spec rain_card_icon_glyph(:loading | {:ok, Forecast.t()} | {:error, term()}) ::
          String.t() | nil
  defp rain_card_icon_glyph(:loading), do: nil

  defp rain_card_icon_glyph({:ok, %Forecast{} = forecast}) do
    # No rain in the upcoming window. Shows clear 0 days.
    case Forecast.next_rain_day(forecast) do
      %ForecastDay{} -> nil
      nil -> "0"
    end
  end

  defp rain_card_icon_glyph({:error, _reason}), do: nil

  @spec rain_card_tone(:loading | {:ok, Forecast.t()} | {:error, term()}) :: String.t()
  defp rain_card_tone(:loading), do: "sky"

  defp rain_card_tone({:ok, %Forecast{} = forecast}) do
    case Forecast.next_rain_day(forecast) do
      %ForecastDay{} -> "sky"
      nil -> "orange"
    end
  end

  defp rain_card_tone({:error, _reason}), do: "sky"

  @spec rain_card_bottom_text(:loading | {:ok, Forecast.t()} | {:error, term()}) :: String.t()
  defp rain_card_bottom_text(:loading), do: "Checking rain"

  defp rain_card_bottom_text({:ok, %Forecast{} = forecast}) do
    case Forecast.next_rain_day(forecast) do
      %ForecastDay{} -> "Next rain"
      nil -> "No rain"
    end
  end

  defp rain_card_bottom_text({:error, _reason}), do: "No data"

  @spec temperature_range_text(ForecastDay.t()) :: String.t()
  defp temperature_range_text(%ForecastDay{} = forecast_day) do
    "#{forecast_day.min_temperature_c}°C/#{forecast_day.max_temperature_c}°C"
  end

  @spec rain_day_label(Forecast.t(), Date.t()) :: String.t()
  defp rain_day_label(%Forecast{} = forecast, %Date{} = rain_day) do
    cond do
      match?(%ForecastDay{date: ^rain_day}, Forecast.today_day(forecast)) -> "Today"
      match?(%ForecastDay{date: ^rain_day}, Forecast.tomorrow_day(forecast)) -> "Tomorrow"
      true -> Calendar.strftime(rain_day, "%A")
    end
  end

  @spec weather_code_icon_name(ForecastDay.t() | nil, String.t()) :: String.t()
  defp weather_code_icon_name(%ForecastDay{weather_code: weather_code}, _),
    do: weather_code_icon_name(weather_code)

  defp weather_code_icon_name(nil, fallback), do: fallback

  @spec weather_code_icon_name(integer()) :: String.t()
  # We don't need proper handling for every provider code.
  # We just need a small icon vocabulary (might need to be extended)
  defp weather_code_icon_name(code) when code in [0, 1], do: "sun"
  defp weather_code_icon_name(2), do: "cloud-sun"
  defp weather_code_icon_name(3), do: "cloud"
  defp weather_code_icon_name(code) when code in [45, 48], do: "haze"
  defp weather_code_icon_name(code) when code in [51, 53, 55, 56, 57], do: "cloud-drizzle"
  defp weather_code_icon_name(code) when code in [61, 63, 65, 66, 67], do: "cloud-rain"
  defp weather_code_icon_name(code) when code in [71, 73, 75, 77, 85, 86], do: "cloud"
  defp weather_code_icon_name(code) when code in [80, 81, 82, 95, 96, 99], do: "cloud-rain"
  defp weather_code_icon_name(_), do: "cloud"

  @spec weather_tone_for_icon_name(String.t()) :: String.t()
  defp weather_tone_for_icon_name(icon_name) when icon_name in ["sun", "cloud-sun", "haze"],
    do: "amber"

  defp weather_tone_for_icon_name(_), do: "sky"

  @spec weather_icon_class(String.t()) :: String.t()
  defp weather_icon_class("amber"), do: "text-amber-500"
  defp weather_icon_class("orange"), do: "text-orange-500"
  defp weather_icon_class(_), do: "text-sky-600"

  @spec weather_glyph_class(String.t(), String.t() | nil) :: String.t()
  defp weather_glyph_class("orange", "0"), do: "text-orange-500"
  defp weather_glyph_class(_, _), do: "text-sky-600"
end
