defmodule Water.Garden do
  @moduledoc """
  The garden facade:
   - CRUDs for board sections and care items.
   - Care commands (via Commands).
  """

  alias Water.Garden.{
    Board,
    Board.Query,
    CareItem,
    CareItemDetail,
    CareItemCard,
    CareItems,
    Commands,
    Schedule,
    ScheduleSuggestion,
    Section,
    Sections
  }

  alias Water.Households.{Household, Member}

  @type result(value) :: {:ok, value} | {:error, Ecto.Changeset.t()}

  @spec list_board(Household.t(), Board.filter(), Date.t()) :: Board.t()
  def list_board(%Household{} = household, filter, %Date{} = today),
    do: Query.list_board(household, filter, today)

  @spec list_sections(Household.t()) :: [Section.t()]
  defdelegate list_sections(household), to: Sections

  @spec list_household_items(Household.t()) :: [CareItem.t()]
  defdelegate list_household_items(household), to: CareItems

  @spec get_section!(Household.t(), Section.id()) :: Section.t()
  defdelegate get_section!(household, id), to: Sections

  @spec create_section(Household.t(), map()) :: result(Section.t())
  defdelegate create_section(household, attrs), to: Sections

  @spec change_section(Section.t(), map()) :: Ecto.Changeset.t()
  def change_section(%Section{} = section, attrs \\ %{}) when is_map(attrs) do
    Sections.change_section(section, attrs)
  end

  @spec update_section(Section.t(), map()) :: result(Section.t())
  defdelegate update_section(section, attrs), to: Sections

  @spec delete_section(Section.t()) :: result(Section.t())
  defdelegate delete_section(section), to: Sections

  @spec get_item!(Household.t(), integer()) :: CareItem.t()
  defdelegate get_item!(household, id), to: CareItems

  @spec get_item_card!(Household.t(), integer(), Date.t()) :: CareItemCard.t()
  defdelegate get_item_card!(household, id, today), to: CareItems

  @spec get_item_detail!(Household.t(), integer(), Date.t()) :: CareItemDetail.t()
  defdelegate get_item_detail!(household, id, today), to: CareItems

  @spec new_item_changeset(Household.t(), map()) :: Ecto.Changeset.t()
  def new_item_changeset(%Household{} = household, attrs \\ %{}) when is_map(attrs) do
    CareItems.new_item_changeset(household, attrs)
  end

  @spec create_item(Household.t(), map()) :: result(CareItem.t())
  defdelegate create_item(household, attrs), to: CareItems

  @spec change_item(CareItem.t(), map()) :: Ecto.Changeset.t()
  def change_item(%CareItem{} = care_item, attrs \\ %{}) when is_map(attrs) do
    CareItems.change_item(care_item, attrs)
  end

  @spec update_item(CareItem.t(), Member.t(), map()) ::
          {:ok, CareItem.t()} | {:error, :member_household_mismatch | Ecto.Changeset.t()}
  defdelegate update_item(care_item, member, attrs), to: CareItems

  @spec delete_item(CareItem.t(), Member.t()) ::
          {:ok, CareItem.t()} | {:error, :member_household_mismatch | Ecto.Changeset.t()}
  defdelegate delete_item(care_item, member), to: CareItems

  @spec reposition_item(Household.t(), Member.t(), CareItem.id(), [CareItems.section_order()]) ::
          {:ok, CareItem.t()} | {:error, CareItems.reposition_error()}
  defdelegate reposition_item(household, member, item_id, section_orders), to: CareItems

  @spec water_item(CareItem.t(), Member.t(), Date.t()) ::
          {:ok, CareItem.t()} | {:error, Commands.command_error()}
  defdelegate water_item(care_item, member, occurred_on), to: Commands

  @spec soil_check_item(CareItem.t(), Member.t(), Schedule.postpone_days(), Date.t()) ::
          {:ok, CareItem.t()} | {:error, Commands.command_error()}
  defdelegate soil_check_item(care_item, member, postpone_days, occurred_on), to: Commands

  @spec mark_item_needs_watering(CareItem.t(), Member.t(), Date.t(), Date.t()) ::
          {:ok, CareItem.t()} | {:error, Commands.command_error()}
  defdelegate mark_item_needs_watering(care_item, member, target_on, occurred_on), to: Commands

  @spec clear_schedule_item(CareItem.t(), Member.t(), Date.t()) ::
          {:ok, CareItem.t()} | {:error, Commands.command_error()}
  defdelegate clear_schedule_item(care_item, member, occurred_on), to: Commands

  @spec suggest_after_watering(CareItem.t(), Date.t()) :: ScheduleSuggestion.t() | nil
  defdelegate suggest_after_watering(care_item, occurred_on), to: ScheduleSuggestion

  @spec apply_schedule_suggestion(CareItem.t(), Member.t(), ScheduleSuggestion.t()) ::
          {:ok, CareItem.t()}
          | {:error, :member_household_mismatch | :suggestion_item_mismatch | Ecto.Changeset.t()}
  defdelegate apply_schedule_suggestion(care_item, member, suggestion), to: CareItems
end
