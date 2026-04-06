defmodule Water.Garden.CommandPersistence do
  @moduledoc false

  alias Ecto.Multi

  alias Water.Garden.{CareEvent, CareItem, Schedule}
  alias Water.Households.Member
  alias Water.Repo

  @type result() :: {:ok, CareItem.t()} | {:error, :stale | Ecto.Changeset.t()}
  @tracked_transition_fields [
    :watering_interval_days,
    :next_due_on,
    :manual_due_on,
    :last_watered_on,
    :last_checked_on,
    :last_care_event_on
  ]

  @spec no_state_change?(CareItem.t(), Schedule.Transition.t()) :: boolean()
  def no_state_change?(%CareItem{} = care_item, %Schedule.Transition{} = transition) do
    attrs = transition_attrs(care_item, transition)

    Enum.all?(@tracked_transition_fields, fn field ->
      Map.fetch!(attrs, field) == Map.get(care_item, field)
    end)
  end

  @spec persist_transition(CareItem.t(), Member.t(), Schedule.Transition.t()) :: result()
  def persist_transition(%CareItem{} = care_item, %Member{} = member, transition) do
    multi = build_command_multi(care_item, member, transition)

    case Repo.transaction(multi) do
      {:ok, %{care_item: updated_care_item}} ->
        {:ok, updated_care_item}

      {:error, :care_item, %Ecto.Changeset{} = changeset, _changes_so_far} ->
        if stale_changeset?(changeset) do
          {:error, :stale}
        else
          {:error, changeset}
        end

      {:error, _step, %Ecto.Changeset{} = changeset, _changes_so_far} ->
        {:error, changeset}
    end
  end

  @dialyzer {:nowarn_function, build_command_multi: 3}
  @spec build_command_multi(CareItem.t(), Member.t(), Schedule.Transition.t()) :: Multi.t()
  defp build_command_multi(%CareItem{} = care_item, %Member{} = member, transition) do
    care_item_changeset =
      CareItem.transition_changeset(care_item, transition_attrs(care_item, transition))

    care_event_changeset =
      CareEvent.changeset(%CareEvent{}, care_item, member, event_attrs(transition))

    multi = Multi.new()
    multi = Multi.update(multi, :care_item, care_item_changeset, stale_error_field: :lock_version)
    Multi.insert(multi, :care_event, care_event_changeset)
  end

  @spec transition_attrs(CareItem.t(), Schedule.Transition.t()) :: map()
  defp transition_attrs(%CareItem{}, transition) do
    %{
      watering_interval_days: transition.watering_interval_days,
      next_due_on: transition.next_due_on,
      manual_due_on: transition.manual_due_on,
      last_watered_on: transition.last_watered_on,
      last_checked_on: transition.last_checked_on,
      last_care_event_on: transition.last_care_event_on
    }
  end

  @spec event_attrs(Schedule.Transition.t()) :: map()
  defp event_attrs(transition) do
    %{
      event_type: transition.event_type,
      occurred_on: transition.occurred_on,
      postpone_days: transition.postpone_days,
      manual_target_on: transition.manual_target_on,
      previous_due_on: transition.previous_due_on,
      resulting_due_on: transition.resulting_due_on
    }
  end

  @spec stale_changeset?(Ecto.Changeset.t()) :: boolean()
  defp stale_changeset?(%Ecto.Changeset{errors: errors}) do
    Enum.any?(errors, fn
      {:lock_version, {_message, opts}} -> Keyword.get(opts, :stale, false)
      _other -> false
    end)
  end
end
