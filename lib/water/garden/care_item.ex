defmodule Water.Garden.CareItem do
  @moduledoc """
  Represents (and validates) a care item in the garden, such as a plant, area, or bed.
  The scheduling is determined by `watering_interval_days`, `next_due_on`, and `manual_due_on` fields.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Water.Garden.{CareEvent, Section}
  alias Water.Households.Household

  @type id() :: pos_integer()
  @type kind() :: :plant | :area | :bed
  @type t() :: %__MODULE__{
          __meta__: Ecto.Schema.Metadata.t(),
          id: id() | nil,
          household_id: Household.id() | nil,
          household: Ecto.Association.NotLoaded.t() | Household.t(),
          section_id: Section.id() | nil,
          section: Ecto.Association.NotLoaded.t() | Section.t(),
          name: String.t() | nil,
          type: kind() | nil,
          watering_interval_days: pos_integer() | nil,
          next_due_on: Date.t() | nil,
          manual_due_on: Date.t() | nil,
          last_watered_on: Date.t() | nil,
          last_checked_on: Date.t() | nil,
          last_care_event_on: Date.t() | nil,
          position: non_neg_integer(),
          lock_version: pos_integer(),
          care_events: Ecto.Association.NotLoaded.t() | [CareEvent.t()],
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "care_items" do
    field :name, :string
    field :type, Ecto.Enum, values: [:plant, :area, :bed]
    field :watering_interval_days, :integer
    field :next_due_on, :date
    field :manual_due_on, :date
    field :last_watered_on, :date
    field :last_checked_on, :date
    field :last_care_event_on, :date
    field :position, :integer, default: 0
    field :lock_version, :integer, default: 1

    belongs_to :household, Household
    belongs_to :section, Section
    has_many :care_events, CareEvent

    timestamps(type: :utc_datetime)
  end

  @spec create_changeset(t(), Household.t(), Section.t(), map()) :: Ecto.Changeset.t()
  # Note that we require ownership on create.
  def create_changeset(
        %__MODULE__{} = care_item,
        %Household{id: household_id},
        %Section{id: section_id},
        attrs
      ) do
    care_item
    |> editable_changeset(attrs)
    |> cast(attrs, [
      :next_due_on,
      :manual_due_on,
      :last_watered_on,
      :last_checked_on,
      :last_care_event_on,
      :lock_version
    ])
    |> put_change(:household_id, household_id)
    |> put_change(:section_id, section_id)
    |> validate_required([
      :name,
      :type,
      :section_id,
      :position,
      :lock_version
    ])
    |> shared_constraints()
  end

  @spec update_changeset(t(), map()) :: Ecto.Changeset.t()
  @doc """
  Ordinary CRUD. Can't mutate event-driven fields.
  """
  def update_changeset(%__MODULE__{} = care_item, attrs) do
    care_item
    |> editable_changeset(attrs)
    |> validate_required([:name, :type, :section_id, :position])
    |> shared_constraints()
  end

  @spec transition_changeset(t(), map()) :: Ecto.Changeset.t()
  @doc """
  For the care transition, not item CRUD (applies the domain event to the persisted state)
  """
  def transition_changeset(%__MODULE__{} = care_item, attrs) do
    care_item
    |> cast(attrs, [
      :watering_interval_days,
      :next_due_on,
      :manual_due_on,
      :last_watered_on,
      :last_checked_on,
      :last_care_event_on
    ])
    |> validate_required([:last_care_event_on])
    |> optimistic_lock(:lock_version)
    |> shared_constraints()
  end

  @spec editable_changeset(t(), map()) :: Ecto.Changeset.t()
  # The fields that are editable by the user (not computed by the system)
  defp editable_changeset(%__MODULE__{} = care_item, attrs) do
    care_item
    |> cast(attrs, [
      :name,
      :type,
      :section_id,
      :watering_interval_days,
      :next_due_on,
      :manual_due_on,
      :position
    ])
  end

  @spec shared_constraints(Ecto.Changeset.t()) :: Ecto.Changeset.t()
  # To enforce the (same) invariants
  defp shared_constraints(changeset) do
    changeset
    |> validate_number(:watering_interval_days, greater_than: 0)
    |> validate_number(:lock_version, greater_than: 0)
    |> assoc_constraint(:household)
    |> assoc_constraint(:section)
    |> unique_constraint(:name, name: :care_items_section_id_name_index)
    |> unique_constraint(:position, name: :care_items_section_id_position_index)
    |> check_constraint(
      :watering_interval_days,
      name: :care_items_watering_interval_days_must_be_positive
    )
    |> check_constraint(:lock_version, name: :care_items_lock_version_must_be_positive)
    |> validate_due_shape()
  end

  @spec validate_due_shape(Ecto.Changeset.t()) :: Ecto.Changeset.t()
  # The due date invariant enforcement:
  # - if interval is set, next_due_on must be present
  # - if interval is nil, next_due_on must be nil
  defp validate_due_shape(changeset) do
    interval = get_field(changeset, :watering_interval_days)
    next_due_on = get_field(changeset, :next_due_on)

    cond do
      is_integer(interval) and interval > 0 and is_nil(next_due_on) ->
        add_error(changeset, :next_due_on, "can't be blank when recurring")

      is_nil(interval) and match?(%Date{}, next_due_on) ->
        add_error(changeset, :next_due_on, "must be blank when schedule mode is no_schedule")

      true ->
        changeset
    end
  end
end
