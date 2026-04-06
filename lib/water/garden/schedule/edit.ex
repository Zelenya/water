defmodule Water.Garden.Schedule.Edit do
  @moduledoc false

  alias Water.Garden.{Attrs, CareItem}

  @type intent() :: :preserve | :recurring | :no_schedule

  @spec normalize_attrs(map(), nil | CareItem.t(), Date.t()) :: map()
  def normalize_attrs(attrs, current_item, %Date{} = occurred_on) do
    intent = schedule_intent(attrs, current_item)
    attrs = Attrs.delete_attr(attrs, :schedule_mode)

    case intent do
      :preserve ->
        attrs

      :no_schedule ->
        attrs
        |> Attrs.put_attr(:watering_interval_days, nil)
        |> Attrs.put_attr(:next_due_on, nil)
        |> Attrs.put_attr(:manual_due_on, nil)

      :recurring ->
        normalize_recurring_attrs(attrs, current_item, occurred_on)
    end
  end

  @spec validate_selection(Ecto.Changeset.t(), map(), nil | CareItem.t()) :: Ecto.Changeset.t()
  def validate_selection(changeset, attrs, current_item) do
    case {schedule_intent(attrs, current_item), Attrs.get_attr(attrs, :watering_interval_days)} do
      {:recurring, raw_interval} when raw_interval in [nil, ""] ->
        Ecto.Changeset.add_error(
          changeset,
          :watering_interval_days,
          "can't be blank when recurring"
        )

      _other ->
        changeset
    end
  end

  @spec schedule_intent(map(), nil | CareItem.t()) :: intent()
  defp schedule_intent(attrs, nil) do
    case cast_schedule_mode(Attrs.get_attr(attrs, :schedule_mode)) do
      mode when mode in [:recurring, :no_schedule] ->
        mode

      nil ->
        if Attrs.has_attr?(attrs, :watering_interval_days), do: :recurring, else: :no_schedule
    end
  end

  defp schedule_intent(attrs, %CareItem{}) do
    case cast_schedule_mode(Attrs.get_attr(attrs, :schedule_mode)) do
      mode when mode in [:recurring, :no_schedule] ->
        mode

      nil ->
        if Attrs.has_attr?(attrs, :watering_interval_days), do: :recurring, else: :preserve
    end
  end

  @spec normalize_recurring_attrs(map(), nil | CareItem.t(), Date.t()) :: map()
  defp normalize_recurring_attrs(attrs, current_item, %Date{} = occurred_on) do
    case cast_interval(Attrs.get_attr(attrs, :watering_interval_days)) do
      {:ok, interval} ->
        attrs
        |> Attrs.put_attr(:watering_interval_days, interval)
        |> Attrs.put_attr(:next_due_on, recurring_due_on(current_item, interval, occurred_on))

      :error ->
        attrs
    end
  end

  @spec recurring_due_on(nil | CareItem.t(), pos_integer(), Date.t()) :: Date.t()
  defp recurring_due_on(nil, interval, %Date{} = occurred_on), do: Date.add(occurred_on, interval)

  defp recurring_due_on(%CareItem{} = care_item, interval, %Date{} = occurred_on) do
    cond do
      care_item.watering_interval_days != interval ->
        Date.add(occurred_on, interval)

      match?(%Date{}, care_item.next_due_on) ->
        care_item.next_due_on

      true ->
        Date.add(occurred_on, interval)
    end
  end

  @spec cast_interval(term()) :: :error | {:ok, pos_integer()}
  defp cast_interval(nil), do: :error
  defp cast_interval(""), do: :error
  defp cast_interval(value) when is_integer(value) and value > 0, do: {:ok, value}

  defp cast_interval(value) do
    case Ecto.Type.cast(:integer, value) do
      {:ok, interval} when is_integer(interval) and interval > 0 -> {:ok, interval}
      _other -> :error
    end
  end

  @spec cast_schedule_mode(term()) :: nil | :recurring | :no_schedule
  defp cast_schedule_mode(:recurring), do: :recurring
  defp cast_schedule_mode("recurring"), do: :recurring
  defp cast_schedule_mode(:no_schedule), do: :no_schedule
  defp cast_schedule_mode("no_schedule"), do: :no_schedule
  defp cast_schedule_mode(_other), do: nil
end
