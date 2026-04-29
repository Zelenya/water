defmodule WaterWeb.Garden.State.CareFeedback do
  @enforce_keys [:item_id, :label]
  defstruct [:item_id, :label, tone: :default]

  alias Water.Garden.CareItem

  # The water one is special, because it's a main action and can have a fun splashy animation.
  @type tone() :: :default | :water

  @type t() :: %__MODULE__{
          item_id: CareItem.id(),
          label: String.t(),
          tone: tone()
        }
end
