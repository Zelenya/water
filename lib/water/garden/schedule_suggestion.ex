defmodule Water.Garden.ScheduleSuggestion do
  @moduledoc """
  Suggests recurring watering schedules from recent watering history.
  """

  import Ecto.Query

  alias Water.Garden.{CareEvent, CareItem}
  alias Water.Repo

  @enforce_keys [
    :care_item_id,
    :current_interval_days,
    :suggested_interval_days,
    :watering_dates,
    :next_due_on
  ]
  defstruct [
    :care_item_id,
    :current_interval_days,
    :suggested_interval_days,
    :watering_dates,
    :next_due_on
  ]

  @defaults [
    required_waterings: 3,
    lookback_days: 30,
    gap_tolerance_days: 1
  ]

  @type t() :: %__MODULE__{
          care_item_id: CareItem.id(),
          current_interval_days: pos_integer() | nil,
          suggested_interval_days: pos_integer(),
          watering_dates: [Date.t()],
          next_due_on: Date.t()
        }

  @spec suggest_after_watering(CareItem.t(), Date.t()) :: t() | nil
  @doc """
  Suggest a new watering schedule based on the watering patterns.
  We take X recent watering to determine the typical interval.

  If the watering matches the current schedule, we don't need to suggest any change.
  """
  def suggest_after_watering(%CareItem{id: item_id} = care_item, %Date{} = occurred_on)
      when is_integer(item_id) do
    config = config()
    watering_dates = care_item |> recent_watering_dates(occurred_on, config)
    # |> Enum.reverse()

    with true <- length(watering_dates) >= config.required_waterings,
         {:ok, suggested_interval} <- suggest_interval(watering_dates, config),
         true <- care_item.watering_interval_days != suggested_interval do
      %__MODULE__{
        care_item_id: item_id,
        current_interval_days: care_item.watering_interval_days,
        suggested_interval_days: suggested_interval,
        watering_dates: watering_dates,
        next_due_on: Date.add(occurred_on, suggested_interval)
      }
    else
      _other -> nil
    end
  end

  def suggest_after_watering(%CareItem{}, %Date{}), do: nil

  @spec recent_watering_dates(CareItem.t(), Date.t(), config()) :: [Date.t()]
  defp recent_watering_dates(%CareItem{id: item_id}, %Date{} = occurred_on, config) do
    # We only want to take into account relevant history.
    # Previous seasons and previous patterns are would skew the suggestion.
    cutoff_on = Date.add(occurred_on, -config.lookback_days)

    from(care_event in CareEvent,
      where:
        care_event.care_item_id == ^item_id and
          care_event.event_type == :watered and
          care_event.occurred_on >= ^cutoff_on and
          care_event.occurred_on <= ^occurred_on,
      order_by: [asc: care_event.occurred_on, asc: care_event.inserted_at],
      select: care_event.occurred_on
    )
    |> Repo.all()
  end

  @spec suggest_interval([Date.t()], config()) :: {:ok, pos_integer()} | :error
  defp suggest_interval(watering_dates, config) do
    gaps =
      watering_dates
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.map(fn [earlier, later] -> Date.diff(later, earlier) end)

    with true <- length(gaps) == length(watering_dates) - 1,
         true <- Enum.all?(gaps, &(&1 > 0)),
         interval <- median_gap(gaps),
         true <- interval > 0,
         true <- Enum.all?(gaps, &(abs(&1 - interval) <= config.gap_tolerance_days)) do
      {:ok, interval}
    else
      _other -> :error
    end
  end

  @spec median_gap([pos_integer()]) :: pos_integer()
  defp median_gap([_ | _] = gaps) do
    sorted = Enum.sort(gaps)
    count = length(sorted)
    mid = div(count, 2)

    case rem(count, 2) do
      1 -> Enum.at(sorted, mid)
      0 -> div(Enum.at(sorted, mid - 1) + Enum.at(sorted, mid) + 1, 2)
    end
  end

  @type config() :: %{
          required(:required_waterings) => pos_integer(),
          required(:lookback_days) => non_neg_integer(),
          required(:gap_tolerance_days) => non_neg_integer()
        }

  @spec config() :: config()
  defp config do
    raw_config = Application.get_env(:water, :schedule_suggestions, [])

    %{
      required_waterings:
        positive_integer_config(raw_config, :required_waterings, @defaults[:required_waterings]),
      lookback_days:
        positive_integer_config(raw_config, :lookback_days, @defaults[:lookback_days]),
      gap_tolerance_days:
        positive_integer_config(
          raw_config,
          :gap_tolerance_days,
          @defaults[:gap_tolerance_days]
        )
    }
  end

  @type raw_config() :: keyword() | %{optional(atom()) => term()} | term()

  @spec positive_integer_config(raw_config(), atom(), pos_integer()) :: pos_integer()
  defp positive_integer_config(config, key, default) do
    case config_value(config, key, default) do
      value when is_integer(value) and value > 0 -> value
      _other -> default
    end
  end

  @spec config_value(raw_config(), atom(), term()) :: term()
  defp config_value(config, key, default) when is_list(config) do
    Keyword.get(config, key, default)
  end

  defp config_value(config, key, default) when is_map(config) do
    Map.get(config, key, default)
  end

  defp config_value(_config, _key, default), do: default
end
