defmodule Water.Garden.CareItemCard do
  @doc """
  A read model for the care item, so the board doesn't need to recompute the item state itself.
  """
  @enforce_keys [
    :item,
    :effective_due_on,
    :status,
    :is_due_today,
    :is_overdue,
    :is_due_tomorrow
  ]
  defstruct [
    :item,
    :effective_due_on,
    :status,
    :is_due_today,
    :is_overdue,
    :is_due_tomorrow
  ]

  alias Water.Garden.{CareItem, Schedule}

  # Care item along with a computed board state.
  @type t() :: %__MODULE__{
          item: CareItem.t(),
          effective_due_on: Date.t() | nil,
          status: Schedule.status(),
          is_due_today: boolean(),
          is_overdue: boolean(),
          is_due_tomorrow: boolean()
        }

  @spec from_item(CareItem.t(), Date.t()) :: t()
  def from_item(%CareItem{} = care_item, %Date{} = today) do
    effective_due_on = Schedule.effective_due_on(care_item)
    tomorrow = Date.add(today, 1)
    status = Schedule.status(care_item, today)

    %__MODULE__{
      item: care_item,
      effective_due_on: effective_due_on,
      status: status,
      is_due_today: due_matches?(effective_due_on, today),
      is_overdue: due_before?(effective_due_on, today),
      is_due_tomorrow: due_matches?(effective_due_on, tomorrow)
    }
  end

  @spec due_matches?(Date.t() | nil, Date.t()) :: boolean()
  defp due_matches?(nil, %Date{}), do: false
  defp due_matches?(%Date{} = due_on, %Date{} = target), do: Date.compare(due_on, target) == :eq

  @spec due_before?(Date.t() | nil, Date.t()) :: boolean()
  defp due_before?(nil, %Date{}), do: false
  defp due_before?(%Date{} = due_on, %Date{} = target), do: Date.compare(due_on, target) == :lt
end
