defmodule Water.Garden.DailyReminder do
  @moduledoc false

  alias Water.Garden.{Board, BoardCounts}
  alias Water.Households.Household

  @default_time "07:00"
  @type config() :: keyword()
  @type t() :: %__MODULE__{
          body: String.t(),
          date: Date.t(),
          notify_at_ms: integer()
        }

  @enforce_keys [:body, :date, :notify_at_ms]
  defstruct [:body, :date, :notify_at_ms]

  @spec from_board(Household.t(), Board.t(), Date.t()) :: t() | nil
  def from_board(%Household{} = household, %Board{} = board, %Date{} = today) do
    from_board(household, board, today, reminder_config())
  end

  @spec from_board(Household.t(), Board.t(), Date.t(), config()) :: t() | nil
  def from_board(
        %Household{} = household,
        %Board{counts: %BoardCounts{} = counts},
        %Date{} = today,
        config
      )
      when is_list(config) do
    with true <- enabled?(config),
         true <- counts.today > 0,
         {:ok, notify_at_ms} <- notify_at_ms(household, today, configured_time(config)) do
      %__MODULE__{
        body: body(counts.overdue, max(counts.today - counts.overdue, 0)),
        date: today,
        notify_at_ms: notify_at_ms
      }
    else
      _other -> nil
    end
  end

  @spec reminder_config() :: config()
  defp reminder_config do
    Application.get_env(:water, :daily_reminders, [])
  end

  @spec enabled?(config()) :: boolean()
  defp enabled?(config), do: Keyword.get(config, :enabled, true)

  @spec configured_time(config()) :: String.t() | Time.t()
  defp configured_time(config), do: Keyword.get(config, :time, @default_time)

  @spec notify_at_ms(Household.t(), Date.t(), String.t() | Time.t()) ::
          {:ok, integer()} | :error
  defp notify_at_ms(%Household{timezone: timezone}, %Date{} = date, time_value) do
    with {:ok, time} <- parse_configured_time(time_value),
         {:ok, date_time} <- new_datetime(date, time, timezone) do
      {:ok, DateTime.to_unix(date_time, :millisecond)}
    else
      _other -> :error
    end
  end

  @spec parse_configured_time(String.t() | Time.t()) :: {:ok, Time.t()} | :error
  defp parse_configured_time(time_value) do
    case parse_time(time_value) do
      {:ok, time} -> {:ok, time}
      :error -> parse_time(@default_time)
    end
  end

  @spec parse_time(String.t() | Time.t()) :: {:ok, Time.t()} | :error
  defp parse_time(%Time{} = time), do: {:ok, Time.truncate(time, :second)}

  defp parse_time(value) when is_binary(value) do
    value
    |> normalize_time_string()
    |> Time.from_iso8601()
    |> case do
      {:ok, time} -> {:ok, Time.truncate(time, :second)}
      {:error, _reason} -> :error
    end
  end

  defp parse_time(_value), do: :error

  @spec normalize_time_string(String.t()) :: String.t()
  defp normalize_time_string(value) do
    case String.split(value, ":") do
      [_hour, _minute] -> value <> ":00"
      _other -> value
    end
  end

  @spec new_datetime(Date.t(), Time.t(), String.t()) :: {:ok, DateTime.t()} | :error
  defp new_datetime(%Date{} = date, %Time{} = time, timezone) when is_binary(timezone) do
    case DateTime.new(date, time, timezone) do
      {:ok, date_time} -> {:ok, date_time}
      {:ambiguous, first_date_time, _second_date_time} -> {:ok, first_date_time}
      {:gap, _before_gap, after_gap} -> {:ok, after_gap}
      {:error, _reason} -> :error
    end
  end

  defp new_datetime(%Date{}, %Time{}, _timezone), do: :error

  @spec body(non_neg_integer(), non_neg_integer()) :: String.t()
  defp body(overdue_count, due_today_count) when overdue_count > 0 and due_today_count > 0 do
    "#{plural(overdue_count, "item")} overdue, #{due_today_count} due today."
  end

  defp body(overdue_count, 0) when overdue_count > 0 do
    "#{plural(overdue_count, "item")} overdue."
  end

  defp body(0, due_today_count) do
    "#{plural(due_today_count, "item")} due today."
  end

  @spec plural(non_neg_integer(), String.t()) :: String.t()
  defp plural(1, noun), do: "1 #{noun}"
  defp plural(count, noun), do: "#{count} #{noun}s"
end
