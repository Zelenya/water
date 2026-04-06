defmodule Water.Garden.Board do
  @enforce_keys [:household, :filter, :counts, :sections, :needs_care_items]
  defstruct [:household, :filter, :counts, :sections, :needs_care_items]

  alias Water.Garden.{BoardCounts, BoardSection, CareItemCard}
  alias Water.Households.Household

  @type filter() :: :all | :today | :tomorrow | :overdue | :no_schedule
  @type t() :: %__MODULE__{
          household: Household.t(),
          filter: filter(),
          counts: BoardCounts.t(),
          sections: [BoardSection.t()],
          needs_care_items: [CareItemCard.t()]
        }
end
