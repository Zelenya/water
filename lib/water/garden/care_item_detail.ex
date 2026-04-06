defmodule Water.Garden.CareItemDetail do
  @enforce_keys [:item_card, :recent_events]
  defstruct [:item_card, :recent_events]

  alias Water.Garden.{CareEvent, CareItemCard}

  @type t() :: %__MODULE__{
          item_card: CareItemCard.t(),
          recent_events: [CareEvent.t()]
        }
end
