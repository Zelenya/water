defmodule Water.Garden.Event do
  @moduledoc """
  Household-scoped realtime garden updates.
  """

  alias Water.Garden.{CareItem, Section}
  alias Water.Households.Household

  @type kind() ::
          :board_changed
          | :care_action_applied
          | :item_changed
          | :item_deleted
          | :section_changed
  @type tone() :: :default | :water

  @type t() :: %__MODULE__{
          household_id: Household.id(),
          kind: kind(),
          item_id: CareItem.id() | nil,
          section_id: Section.id() | nil,
          label: String.t() | nil,
          tone: tone() | nil
        }

  @enforce_keys [:household_id, :kind]
  defstruct [:household_id, :kind, :item_id, :section_id, :label, :tone]
end
