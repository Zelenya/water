defmodule Water.Households.Household do
  @moduledoc """
  Household-level settings and ownership boundary.

  A household is the root record for garden sections, care items, care events,
  and members. Even though the current product uses a single default household,
  keeping those settings here gives the domain a clear place to store local
  time-zone behavior.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Water.Garden.{CareEvent, CareItem, Section}
  alias Water.Households.Member

  @type id() :: pos_integer()
  @type t() :: %__MODULE__{
          __meta__: Ecto.Schema.Metadata.t(),
          id: id() | nil,
          name: String.t() | nil,
          slug: String.t() | nil,
          timezone: String.t() | nil,
          members: Ecto.Association.NotLoaded.t() | [Member.t()],
          sections: Ecto.Association.NotLoaded.t() | [Section.t()],
          care_items: Ecto.Association.NotLoaded.t() | [CareItem.t()],
          care_events: Ecto.Association.NotLoaded.t() | [CareEvent.t()],
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "households" do
    field :name, :string
    field :slug, :string
    field :timezone, :string

    has_many :members, Member
    has_many :sections, Section
    has_many :care_items, CareItem
    has_many :care_events, CareEvent

    timestamps(type: :utc_datetime)
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = household, attrs) do
    household
    |> cast(attrs, [:name, :slug, :timezone])
    |> validate_required([:name, :slug, :timezone])
    |> validate_change(:timezone, &validate_timezone/2)
    |> unique_constraint(:slug)
  end

  @spec validate_timezone(atom(), String.t()) :: [{atom(), String.t()}]
  defp validate_timezone(:timezone, timezone) when is_binary(timezone) do
    # The garden board computes "today" in the household's local timezone, so
    # validating this at the boundary prevents subtle scheduling drift later.
    case DateTime.now(timezone) do
      {:ok, _date_time} ->
        []

      {:error, :time_zone_not_found} ->
        [timezone: "must be a valid IANA time zone"]

      {:error, :utc_only_time_zone_database} ->
        [timezone: "cannot be validated without a configured time zone database"]
    end
  end
end
