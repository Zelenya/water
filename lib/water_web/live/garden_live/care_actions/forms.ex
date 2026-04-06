defmodule WaterWeb.GardenLive.CareActions.Forms do
  import Phoenix.Component, only: [to_form: 2]

  alias Water.Garden.{CareItem, CareItemCard}
  alias WaterWeb.Garden.State.CareAction

  @schedule_form_as :schedule_watering

  @spec schedule_form(CareItemCard.t(), Date.t(), map()) :: Phoenix.HTML.Form.t()
  def schedule_form(%CareItemCard{} = item_card, %Date{} = today, params \\ %{})
      when is_map(params) do
    defaults = %{
      "days" => "",
      "target_on" => Date.to_iso8601(default_schedule_target_on(item_card, today))
    }

    to_form(Map.merge(defaults, params), as: @schedule_form_as)
  end

  @spec parse_postpone_days(nil | String.t()) :: :error | {:ok, pos_integer()}
  def parse_postpone_days(nil), do: :error

  def parse_postpone_days(raw_value) do
    case Integer.parse(raw_value) do
      {value, ""} when value > 0 -> {:ok, value}
      _other -> :error
    end
  end

  @spec schedule_postpone_days(nil | CareAction.t(), nil | String.t(), Date.t()) ::
          :error | {:same_due_on, Date.t()} | {:ok, {:days, pos_integer()}}
  def schedule_postpone_days(
        %CareAction{kind: kind, item_card: %CareItemCard{} = item_card},
        raw_target_on,
        %Date{} = today
      )
      when kind in [:soil_check, :schedule_watering] do
    case parse_target_on(raw_target_on) do
      {:ok, %Date{} = target_on} ->
        case item_card.effective_due_on do
          %Date{} = due_on ->
            case Date.diff(target_on, due_on) do
              days when days > 0 -> {:ok, {:days, days}}
              0 -> {:same_due_on, due_on}
              _other -> :error
            end

          nil ->
            case Date.diff(target_on, today) do
              days when days > 0 -> {:ok, {:days, days}}
              _other -> :error
            end
        end

      :error ->
        :error
    end
  end

  def schedule_postpone_days(_care_action, _raw_target_on, _today), do: :error

  @spec parse_target_on(nil | String.t()) :: :error | {:ok, Date.t()}
  def parse_target_on(nil), do: :error

  def parse_target_on(raw_value) do
    case Date.from_iso8601(raw_value) do
      {:ok, %Date{} = date} -> {:ok, date}
      {:error, _reason} -> :error
    end
  end

  @spec default_schedule_target_on(CareItemCard.t(), Date.t()) :: Date.t()
  defp default_schedule_target_on(%CareItemCard{effective_due_on: nil}, %Date{} = today) do
    Date.add(today, 1)
  end

  defp default_schedule_target_on(
         %CareItemCard{
           effective_due_on: %Date{} = effective_due_on,
           item: %CareItem{watering_interval_days: interval}
         },
         _today
       )
       when is_integer(interval) and interval > 0 do
    Date.add(effective_due_on, interval)
  end

  defp default_schedule_target_on(
         %CareItemCard{effective_due_on: %Date{} = effective_due_on},
         _today
       ) do
    Date.add(effective_due_on, 1)
  end
end
