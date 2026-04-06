defmodule Water.Garden.BoardSectionSummary do
  @enforce_keys [:today, :tomorrow, :overdue]
  defstruct [:today, :tomorrow, :overdue]

  @type t() :: %__MODULE__{
          today: non_neg_integer(),
          tomorrow: non_neg_integer(),
          overdue: non_neg_integer()
        }
end
