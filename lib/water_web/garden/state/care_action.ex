defmodule WaterWeb.Garden.State.CareAction do
  @moduledoc """
  For care workflows forms
  """
  @enforce_keys [:kind, :item_card, :mode, :form]
  defstruct [:kind, :item_card, :mode, :form, error: nil]

  alias Water.Garden.CareItemCard

  @type kind() :: :soil_check | :schedule_watering
  @type mode() :: :custom_date | :custom_days | :picker

  @type t() :: %__MODULE__{
          kind: kind(),
          item_card: CareItemCard.t(),
          mode: mode(),
          form: Phoenix.HTML.Form.t(),
          error: nil | String.t()
        }
end
