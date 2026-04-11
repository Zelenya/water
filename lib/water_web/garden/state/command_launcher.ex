defmodule WaterWeb.Garden.State.CommandLauncher do
  @moduledoc false

  alias WaterWeb.Garden.CommandLauncher.Entry

  @enforce_keys [:open?, :query, :selected_index, :results]
  defstruct [:open?, :query, :selected_index, :results]

  @type t() :: %__MODULE__{
          open?: boolean(),
          query: String.t(),
          selected_index: nil | non_neg_integer(),
          results: [Entry.t()]
        }
end
