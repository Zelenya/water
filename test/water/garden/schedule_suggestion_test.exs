defmodule Water.Garden.ScheduleSuggestionTest do
  use Water.DataCase, async: false

  alias Water.Garden
  alias Water.Garden.{CareEvent, CareItem, ScheduleSuggestion}
  alias Water.GardenFixtures

  setup do
    previous_config = Application.get_env(:water, :schedule_suggestions)

    on_exit(fn ->
      restore_config(previous_config)
    end)

    :ok
  end

  describe "suggest_after_watering/2" do
    test "returns no suggestion with fewer than the required watered events" do
      %{item: item, member: member} = setup_item(%{watering_interval_days: nil, next_due_on: nil})

      insert_waterings(item, member, [~D[2026-03-26], ~D[2026-03-27]])

      assert ScheduleSuggestion.suggest_after_watering(item, ~D[2026-03-27]) == nil
    end

    test "returns no suggestion when older events fall outside the lookback" do
      %{item: item, member: member} = setup_item(%{watering_interval_days: nil, next_due_on: nil})

      insert_waterings(item, member, [~D[2026-02-24], ~D[2026-03-26], ~D[2026-03-27]])

      assert ScheduleSuggestion.suggest_after_watering(item, ~D[2026-03-27]) == nil
    end

    test "suggests daily watering from three consecutive waterings" do
      %{item: item, member: member} = setup_item(%{watering_interval_days: nil, next_due_on: nil})

      insert_waterings(item, member, [~D[2026-03-25], ~D[2026-03-26], ~D[2026-03-27]])

      assert %ScheduleSuggestion{} =
               suggestion = ScheduleSuggestion.suggest_after_watering(item, ~D[2026-03-27])

      assert suggestion.current_interval_days == nil
      assert suggestion.suggested_interval_days == 1
      assert suggestion.next_due_on == ~D[2026-03-28]
      assert suggestion.watering_dates == [~D[2026-03-25], ~D[2026-03-26], ~D[2026-03-27]]
    end

    test "suggests weekly watering from weekly gaps" do
      %{item: item, member: member} = setup_item(%{watering_interval_days: 1})

      insert_waterings(item, member, [~D[2026-03-13], ~D[2026-03-20], ~D[2026-03-27]])

      assert %ScheduleSuggestion{suggested_interval_days: 7} =
               ScheduleSuggestion.suggest_after_watering(item, ~D[2026-03-27])
    end

    test "uses tolerant median gaps for close watering history" do
      %{item: item, member: member} = setup_item(%{watering_interval_days: nil, next_due_on: nil})

      insert_waterings(item, member, [~D[2026-03-13], ~D[2026-03-19], ~D[2026-03-27]])

      assert %ScheduleSuggestion{suggested_interval_days: 7} =
               ScheduleSuggestion.suggest_after_watering(item, ~D[2026-03-27])
    end

    test "ignores an older gap outside the median tolerance" do
      %{item: item, member: member} = setup_item(%{watering_interval_days: nil, next_due_on: nil})

      insert_waterings(
        item,
        member,
        [~D[2026-07-02], ~D[2026-07-19], ~D[2026-07-25], ~D[2026-07-31]]
      )

      assert %ScheduleSuggestion{suggested_interval_days: 6, next_due_on: ~D[2026-08-06]} =
               ScheduleSuggestion.suggest_after_watering(item, ~D[2026-07-31])
    end

    test "suggests the median when sixty percent of recent gaps are within three days" do
      Application.put_env(:water, :schedule_suggestions, %{lookback_days: 45})

      %{item: item, member: member} = setup_item(%{watering_interval_days: nil, next_due_on: nil})

      insert_waterings(item, member, [
        ~D[2026-06-01],
        ~D[2026-06-08],
        ~D[2026-06-13],
        ~D[2026-06-23],
        ~D[2026-06-30],
        ~D[2026-07-06]
      ])

      assert %ScheduleSuggestion{suggested_interval_days: 7} =
               ScheduleSuggestion.suggest_after_watering(item, ~D[2026-07-06])
    end

    test "returns no suggestion without at least two gaps supporting the median" do
      %{item: item, member: member} = setup_item(%{watering_interval_days: nil, next_due_on: nil})

      insert_waterings(
        item,
        member,
        [~D[2026-03-02], ~D[2026-03-03], ~D[2026-03-12], ~D[2026-03-27]]
      )

      assert ScheduleSuggestion.suggest_after_watering(item, ~D[2026-03-27]) == nil
    end

    test "returns no suggestion when the current interval already matches" do
      %{item: item, member: member} = setup_item(%{watering_interval_days: 1})

      insert_waterings(item, member, [~D[2026-03-25], ~D[2026-03-26], ~D[2026-03-27]])

      assert ScheduleSuggestion.suggest_after_watering(item, ~D[2026-03-27]) == nil
    end

    test "honors configured waterings, lookback, and tolerance" do
      Application.put_env(:water, :schedule_suggestions, %{
        required_waterings: 4,
        lookback_days: 6,
        gap_tolerance_days: 0
      })

      %{item: item, member: member} = setup_item(%{watering_interval_days: nil, next_due_on: nil})

      insert_waterings(
        item,
        member,
        [~D[2026-03-21], ~D[2026-03-23], ~D[2026-03-26], ~D[2026-03-27]]
      )

      assert ScheduleSuggestion.suggest_after_watering(item, ~D[2026-03-27]) == nil

      Repo.delete_all(Water.Garden.CareEvent)

      insert_waterings(item, member, [
        ~D[2026-03-24],
        ~D[2026-03-25],
        ~D[2026-03-26],
        ~D[2026-03-27]
      ])

      assert %ScheduleSuggestion{suggested_interval_days: 1} =
               ScheduleSuggestion.suggest_after_watering(item, ~D[2026-03-27])
    end
  end

  describe "apply_schedule_suggestion/3" do
    test "applies the exact suggested next due date" do
      %{item: item, member: member} = setup_item(%{watering_interval_days: nil, next_due_on: nil})

      suggestion = %ScheduleSuggestion{
        care_item_id: item.id,
        current_interval_days: nil,
        suggested_interval_days: 7,
        watering_dates: [~D[2026-03-13], ~D[2026-03-20], ~D[2026-03-27]],
        next_due_on: ~D[2026-04-03]
      }

      assert {:ok, updated_item} = Garden.apply_schedule_suggestion(item, member, suggestion)

      assert updated_item.watering_interval_days == 7
      assert updated_item.next_due_on == ~D[2026-04-03]
      assert updated_item.manual_due_on == nil

      event = Repo.one!(from(care_event in CareEvent, where: care_event.care_item_id == ^item.id))

      assert event.event_type == :schedule_changed
      assert event.resulting_due_on == ~D[2026-04-03]
    end

    test "rejects suggestions for a different item" do
      %{item: item, member: member} = setup_item(%{watering_interval_days: nil, next_due_on: nil})

      other_item =
        GardenFixtures.care_item_fixture(Repo.get!(Water.Garden.Section, item.section_id), %{
          position: 1
        })

      suggestion = %ScheduleSuggestion{
        care_item_id: other_item.id,
        current_interval_days: nil,
        suggested_interval_days: 7,
        watering_dates: [~D[2026-03-13], ~D[2026-03-20], ~D[2026-03-27]],
        next_due_on: ~D[2026-04-03]
      }

      assert Garden.apply_schedule_suggestion(item, member, suggestion) ==
               {:error, :suggestion_item_mismatch}

      assert Repo.get!(CareItem, item.id).watering_interval_days == nil
    end
  end

  defp setup_item(attrs) do
    household = GardenFixtures.household_fixture()
    member = GardenFixtures.member_fixture(household)
    section = GardenFixtures.section_fixture(household)
    item = GardenFixtures.care_item_fixture(section, attrs)

    %{item: item, member: member}
  end

  defp insert_waterings(item, member, dates) do
    Enum.each(dates, fn date ->
      GardenFixtures.care_event_fixture(item, member, %{
        event_type: :watered,
        occurred_on: date
      })
    end)
  end

  defp restore_config(nil), do: Application.delete_env(:water, :schedule_suggestions)
  defp restore_config(config), do: Application.put_env(:water, :schedule_suggestions, config)
end
