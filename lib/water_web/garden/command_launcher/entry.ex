defmodule WaterWeb.Garden.CommandLauncher.Entry do
  @moduledoc """
  Entry is a search result for the command launcher.

  TODO: Consider making a better/explicit sum type instead of one entry.
  """

  alias Water.Garden.Schedule
  alias Water.Garden.{Board, CareItem}
  alias WaterWeb.Garden.State.ToolMode

  @enforce_keys [
    :id,
    :title,
    :subtitle,
    :group,
    :icon_name,
    :icon_type,
    :keywords,
    :action,
    :selectable?,
    :current?,
    :status
  ]
  defstruct [
    :id,
    :title,
    :subtitle,
    :group,
    :icon_name,
    :icon_type,
    :keywords,
    :action,
    :selectable?,
    :current?,
    :status
  ]

  @type group() :: :commands | :items
  @type icon_type() :: :garden | :hero
  @type action() ::
          {:set_tool_mode, ToolMode.t()}
          | {:set_filter, Board.filter()}
          | :new_item
          | :rain
          | {:show_item, CareItem.id()}

  @type t() :: %__MODULE__{
          id: String.t(),
          title: String.t(),
          subtitle: String.t(),
          group: group(),
          icon_name: String.t(),
          icon_type: icon_type(),
          keywords: [String.t()],
          action: action(),
          selectable?: boolean(),
          current?: boolean(),
          status: nil | Schedule.status()
        }
end
