defmodule WaterWeb.Garden.State.Modal do
  @moduledoc """
  For item CRUD forms
  """
  @enforce_keys [:kind, :title, :close_path]
  defstruct [
    :kind,
    :title,
    :close_path,
    :schedule_mode,
    form: nil,
    item_card: nil,
    item_detail: nil
  ]

  alias Water.Garden.{CareItemCard, CareItemDetail}

  @type kind() :: :new_form | :edit_form | :new_unavailable | :show_detail

  @type t() :: %__MODULE__{
          kind: kind(),
          title: String.t(),
          close_path: String.t(),
          schedule_mode: nil | :recurring | :no_schedule,
          form: nil | Phoenix.HTML.Form.t(),
          item_card: nil | CareItemCard.t(),
          item_detail: nil | CareItemDetail.t()
        }
end
