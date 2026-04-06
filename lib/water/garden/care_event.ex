defmodule Water.Garden.CareEvent do
  use Ecto.Schema
  import Ecto.Changeset

  alias Water.Garden.CareItem
  alias Water.Households.{Household, Member}

  @event_rules %{
    soil_checked: %{
      required: [:postpone_days, :resulting_due_on],
      absent: [:manual_target_on]
    },
    manual_needs_watering: %{
      required: [:manual_target_on, :resulting_due_on],
      absent: [:postpone_days]
    },
    watered: %{required: [], absent: [:postpone_days, :manual_target_on]},
    schedule_changed: %{required: [], absent: [:postpone_days, :manual_target_on]}
  }

  @type id() :: pos_integer()
  @type event_type() ::
          :watered | :soil_checked | :manual_needs_watering | :schedule_changed
  @type t() :: %__MODULE__{
          __meta__: Ecto.Schema.Metadata.t(),
          id: id() | nil,
          household_id: Household.id() | nil,
          household: Ecto.Association.NotLoaded.t() | Household.t(),
          care_item_id: CareItem.id() | nil,
          care_item: Ecto.Association.NotLoaded.t() | CareItem.t(),
          actor_member_id: Member.id() | nil,
          actor_member: Ecto.Association.NotLoaded.t() | Member.t(),
          event_type: event_type() | nil,
          occurred_on: Date.t() | nil,
          postpone_days: pos_integer() | nil,
          manual_target_on: Date.t() | nil,
          previous_due_on: Date.t() | nil,
          resulting_due_on: Date.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "care_events" do
    field :event_type, Ecto.Enum,
      values: [:watered, :soil_checked, :manual_needs_watering, :schedule_changed]

    field :occurred_on, :date
    field :postpone_days, :integer
    field :manual_target_on, :date
    field :previous_due_on, :date
    field :resulting_due_on, :date

    belongs_to :household, Household
    belongs_to :care_item, CareItem
    belongs_to :actor_member, Member

    timestamps(type: :utc_datetime)
  end

  @spec changeset(t(), CareItem.t(), Member.t(), map()) :: Ecto.Changeset.t()
  def changeset(
        %__MODULE__{} = care_event,
        %CareItem{id: care_item_id, household_id: household_id},
        %Member{id: actor_member_id, household_id: household_id},
        attrs
      ) do
    care_event
    |> cast(attrs, [
      :event_type,
      :occurred_on,
      :postpone_days,
      :manual_target_on,
      :previous_due_on,
      :resulting_due_on
    ])
    |> put_change(:household_id, household_id)
    |> put_change(:care_item_id, care_item_id)
    |> put_change(:actor_member_id, actor_member_id)
    |> validate_required([
      :household_id,
      :care_item_id,
      :actor_member_id,
      :event_type,
      :occurred_on
    ])
    |> validate_event_rules()
    |> validate_number(:postpone_days, greater_than: 0)
    |> assoc_constraint(:household)
    |> assoc_constraint(:care_item)
    |> assoc_constraint(:actor_member)
    |> check_constraint(
      :postpone_days,
      name: :care_events_postpone_days_must_be_positive_when_present
    )
  end

  @spec validate_event_rules(Ecto.Changeset.t()) :: Ecto.Changeset.t()
  defp validate_event_rules(changeset) do
    case Map.get(@event_rules, get_field(changeset, :event_type)) do
      %{required: required_fields, absent: absent_fields} ->
        changeset
        |> validate_required(required_fields)
        |> validate_absent_fields(absent_fields)

      nil ->
        changeset
    end
  end

  @spec validate_absent_fields(Ecto.Changeset.t(), [atom()]) :: Ecto.Changeset.t()
  defp validate_absent_fields(changeset, fields) do
    Enum.reduce(fields, changeset, fn field, acc ->
      validate_absence(acc, field, get_field(acc, field))
    end)
  end

  @spec validate_absence(Ecto.Changeset.t(), atom(), term()) :: Ecto.Changeset.t()
  defp validate_absence(changeset, _field, nil), do: changeset

  defp validate_absence(changeset, field, _value) do
    add_error(changeset, field, "must be blank for this event type")
  end
end
