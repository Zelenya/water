defmodule Water.Garden.Events do
  @moduledoc """
  PubSub boundary for garden board updates (per household).
  """

  alias Water.Garden.{CareItem, Event, Section}
  alias Water.Households.Household

  @topic_prefix "garden:household:"

  @spec subscribe(Household.t()) :: :ok | {:error, term()}
  def subscribe(%Household{id: household_id}) do
    Phoenix.PubSub.subscribe(Water.PubSub, topic(household_id))
  end

  @spec broadcast_board_changed(Household.t()) :: :ok | {:error, term()}
  def broadcast_board_changed(%Household{id: household_id}) do
    broadcast(%Event{household_id: household_id, kind: :board_changed})
  end

  @spec broadcast_care_action_applied(
          Household.t(),
          CareItem.id(),
          String.t(),
          Event.tone()
        ) :: :ok | {:error, term()}
  def broadcast_care_action_applied(%Household{id: household_id}, item_id, label, tone)
      when is_integer(item_id) and is_binary(label) and tone in [:default, :water] do
    broadcast(%Event{
      household_id: household_id,
      kind: :care_action_applied,
      item_id: item_id,
      label: label,
      tone: tone
    })
  end

  @spec broadcast_item_changed(CareItem.t()) :: :ok | {:error, term()}
  def broadcast_item_changed(%CareItem{id: item_id, household_id: household_id}) do
    broadcast(%Event{household_id: household_id, kind: :item_changed, item_id: item_id})
  end

  @spec broadcast_item_deleted(CareItem.t()) :: :ok | {:error, term()}
  def broadcast_item_deleted(%CareItem{id: item_id, household_id: household_id}) do
    broadcast(%Event{household_id: household_id, kind: :item_deleted, item_id: item_id})
  end

  @spec broadcast_section_changed(Section.t()) :: :ok | {:error, term()}
  def broadcast_section_changed(%Section{id: section_id, household_id: household_id}) do
    broadcast(%Event{household_id: household_id, kind: :section_changed, section_id: section_id})
  end

  @spec broadcast(Event.t()) :: :ok | {:error, term()}
  def broadcast(%Event{household_id: household_id} = event) do
    Phoenix.PubSub.broadcast_from(Water.PubSub, self(), topic(household_id), {__MODULE__, event})
  end

  @spec topic(Household.id()) :: String.t()
  defp topic(household_id), do: @topic_prefix <> Integer.to_string(household_id)
end
