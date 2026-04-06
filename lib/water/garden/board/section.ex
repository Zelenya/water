defmodule Water.Garden.BoardSection do
  @enforce_keys [:section, :summary, :items]
  defstruct [:section, :summary, :items]

  alias Water.Garden.{BoardSectionSummary, CareItemCard, Section}

  @type t() :: %__MODULE__{
          section: Section.t(),
          summary: BoardSectionSummary.t(),
          items: [CareItemCard.t()]
        }
end
