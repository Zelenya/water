defmodule WaterWeb.Garden.State.CareFeedback do
  @enforce_keys [:item_id, :label]
  defstruct [:item_id, :label]

  alias Water.Garden.CareItem

  @type t() :: %__MODULE__{
          item_id: CareItem.id(),
          label: String.t()
        }
end
