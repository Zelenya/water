defmodule Water.Households.Member do
  @moduledoc """
  Household member identity used for attribution and active-session context.

  Members are lightweight on purpose. Today they serve two main jobs:

  - identify who is currently acting in the UI
  - attribute care events to a person in the household

  They are not a full user-account model with passwords or permissions; browser
  auth maps onto members at the edge of the system.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Water.Garden.CareEvent
  alias Water.Households.Household

  @type id() :: pos_integer()
  @type t() :: %__MODULE__{
          __meta__: Ecto.Schema.Metadata.t(),
          id: id() | nil,
          household_id: Household.id() | nil,
          household: Ecto.Association.NotLoaded.t() | Household.t(),
          name: String.t() | nil,
          color: String.t() | nil,
          active: boolean(),
          care_events: Ecto.Association.NotLoaded.t() | [CareEvent.t()],
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "household_members" do
    field :name, :string
    field :color, :string
    field :active, :boolean, default: true

    belongs_to :household, Household
    has_many :care_events, CareEvent, foreign_key: :actor_member_id

    timestamps(type: :utc_datetime)
  end

  @spec create_changeset(t(), Household.t(), map()) :: Ecto.Changeset.t()
  def create_changeset(%__MODULE__{} = member, %Household{id: household_id}, attrs) do
    member
    |> changeset(attrs)
    |> put_change(:household_id, household_id)
  end

  @spec update_changeset(t(), map()) :: Ecto.Changeset.t()
  def update_changeset(%__MODULE__{} = member, attrs) do
    changeset(member, attrs)
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  defp changeset(%__MODULE__{} = member, attrs) do
    member
    |> cast(attrs, [:name, :color, :active])
    # Names act as the stable human credential for the simple auth flow, so we
    # normalize whitespace before the case-insensitive uniqueness check runs.
    |> update_change(:name, &String.trim/1)
    |> validate_required([:name, :active])
    |> assoc_constraint(:household)
    |> unique_constraint(:name, name: :household_members_household_id_lower_name_index)
  end
end
