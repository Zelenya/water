defmodule WaterWeb.Garden.State.ScheduleSuggestion do
  @moduledoc false

  @enforce_keys [
    :item_card,
    :suggestion
  ]
  defstruct [
    :item_card,
    :suggestion
  ]

  alias Water.Garden.CareItemCard
  alias Water.Garden.ScheduleSuggestion, as: GardenScheduleSuggestion

  @type t() :: %__MODULE__{
          item_card: CareItemCard.t(),
          suggestion: GardenScheduleSuggestion.t()
        }
end
