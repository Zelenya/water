defmodule Water.Garden.Section do
  use Ecto.Schema
  import Ecto.Changeset

  alias Water.Garden.CareItem
  alias Water.Households.Household

  @type id() :: pos_integer()
  @type t() :: %__MODULE__{
          __meta__: Ecto.Schema.Metadata.t(),
          id: id() | nil,
          household_id: Household.id() | nil,
          household: Ecto.Association.NotLoaded.t() | Household.t(),
          name: String.t() | nil,
          position: non_neg_integer(),
          care_items: Ecto.Association.NotLoaded.t() | [CareItem.t()],
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "sections" do
    field :name, :string
    field :position, :integer, default: 0

    belongs_to :household, Household
    has_many :care_items, CareItem

    timestamps(type: :utc_datetime)
  end

  @spec create_changeset(t(), Household.t(), map()) :: Ecto.Changeset.t()
  def create_changeset(%__MODULE__{} = section, %Household{id: household_id}, attrs) do
    section
    |> changeset(attrs)
    |> put_change(:household_id, household_id)
  end

  @spec update_changeset(t(), map()) :: Ecto.Changeset.t()
  def update_changeset(%__MODULE__{} = section, attrs) do
    changeset(section, attrs)
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  defp changeset(%__MODULE__{} = section, attrs) do
    section
    |> cast(attrs, [:name, :position])
    |> validate_required([:name, :position])
    |> assoc_constraint(:household)
    |> unique_constraint(:name, name: :sections_household_id_name_index)
    |> unique_constraint(:position, name: :sections_household_id_position_index)
  end
end
