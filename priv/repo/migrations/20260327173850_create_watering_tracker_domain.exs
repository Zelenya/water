defmodule Water.Repo.Migrations.CreateWateringTrackerDomain do
  use Ecto.Migration

  def change do
    create table(:households) do
      add :name, :string, null: false
      add :slug, :string, null: false
      add :timezone, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:households, [:slug])

    create table(:household_members) do
      add :household_id, references(:households, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :color, :string
      add :active, :boolean, null: false, default: true

      timestamps(type: :utc_datetime)
    end

    create index(:household_members, [:household_id])

    create unique_index(:household_members, [:household_id, "lower(btrim(name))"],
             name: :household_members_household_id_lower_name_index
           )

    create table(:sections) do
      add :household_id, references(:households, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :position, :integer, null: false, default: 0

      timestamps(type: :utc_datetime)
    end

    create index(:sections, [:household_id])
    create unique_index(:sections, [:household_id, :name])
    create unique_index(:sections, [:household_id, :position])

    create table(:care_items) do
      add :household_id, references(:households, on_delete: :delete_all), null: false
      add :section_id, references(:sections), null: false
      add :name, :string, null: false
      add :type, :string, null: false
      add :watering_interval_days, :integer
      add :next_due_on, :date
      add :manual_due_on, :date
      add :last_watered_on, :date
      add :last_checked_on, :date
      add :last_care_event_on, :date
      add :position, :integer, null: false, default: 0
      add :lock_version, :integer, null: false, default: 1

      timestamps(type: :utc_datetime)
    end

    create index(:care_items, [:household_id])
    create index(:care_items, [:section_id])
    create index(:care_items, [:next_due_on])
    create index(:care_items, [:manual_due_on])
    create unique_index(:care_items, [:section_id, :name])
    create unique_index(:care_items, [:section_id, :position])

    create constraint(
             :care_items,
             :care_items_watering_interval_days_must_be_positive,
             check: "watering_interval_days IS NULL OR watering_interval_days > 0"
           )

    create constraint(
             :care_items,
             :care_items_lock_version_must_be_positive,
             check: "lock_version > 0"
           )

    create table(:care_events) do
      add :household_id, references(:households, on_delete: :delete_all), null: false
      add :care_item_id, references(:care_items), null: false
      add :actor_member_id, references(:household_members), null: false
      add :event_type, :string, null: false
      add :occurred_on, :date, null: false
      add :postpone_days, :integer
      add :manual_target_on, :date
      add :previous_due_on, :date
      add :resulting_due_on, :date

      timestamps(type: :utc_datetime)
    end

    create index(:care_events, [:household_id])
    create index(:care_events, [:care_item_id])
    create index(:care_events, [:actor_member_id])
    create index(:care_events, [:occurred_on])
    create index(:care_events, [:care_item_id, :occurred_on])

    create constraint(
             :care_events,
             :care_events_postpone_days_must_be_positive_when_present,
             check: "postpone_days IS NULL OR postpone_days > 0"
           )
  end
end
