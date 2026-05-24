defmodule Water.Garden.DailyReminderTest do
  use ExUnit.Case, async: true

  alias Water.Garden.{Board, BoardCounts, DailyReminder}
  alias Water.Households.Household

  describe "from_board/4" do
    test "builds a reminder with expected body and timestamp" do
      today = ~D[2026-05-23]

      reminder =
        household()
        |> DailyReminder.from_board(board(%{today: 4, overdue: 1}), today,
          enabled: true,
          time: "07:00"
        )

      assert %DailyReminder{} = reminder
      assert reminder.date == today
      assert reminder.body == "1 item overdue, 3 due today."
      assert reminder.notify_at_ms == unix_ms(today, ~T[07:00:00], "America/Los_Angeles")
    end

    test "returns nil when reminders are disabled" do
      today = ~D[2026-05-23]

      assert DailyReminder.from_board(
               household(),
               board(%{today: 1, overdue: 0}),
               today,
               enabled: false,
               time: "07:00"
             ) == nil
    end

    test "returns nil when no items need care" do
      today = ~D[2026-05-23]

      assert DailyReminder.from_board(
               household(),
               board(%{today: 0, overdue: 0}),
               today,
               enabled: true,
               time: "07:00"
             ) == nil
    end
  end

  @spec household() :: Household.t()
  defp household do
    %Household{id: 1, timezone: "America/Los_Angeles"}
  end

  @spec board(%{required(:today) => non_neg_integer(), required(:overdue) => non_neg_integer()}) ::
          Board.t()
  defp board(%{today: today, overdue: overdue}) do
    %Board{
      household: household(),
      filter: :all,
      counts: %BoardCounts{today: today, tomorrow: 0, overdue: overdue},
      sections: [],
      needs_care_items: []
    }
  end

  @spec unix_ms(Date.t(), Time.t(), String.t()) :: integer()
  defp unix_ms(%Date{} = date, %Time{} = time, timezone) do
    {:ok, date_time} = DateTime.new(date, time, timezone)
    DateTime.to_unix(date_time, :millisecond)
  end
end
