defmodule Water.Garden.Board.Query do
  @moduledoc """
  The board is a read model assembled from base entities. This is where the assembly magic happens.
  The urgency care items are determined by schedule, and the raw items are grouped by section.
  """

  alias Water.Garden.{
    Board,
    BoardCounts,
    BoardSection,
    BoardSectionSummary,
    CareItem,
    CareItemCard,
    CareItems,
    Schedule,
    Section,
    Sections
  }

  alias Water.Households.Household

  @spec list_board(Household.t(), Board.filter(), Date.t()) :: Board.t()
  @doc """
  Builds the whole household board, including sections, summaries/counts, and items that need care.
  """
  def list_board(%Household{} = household, filter, %Date{} = today) do
    sections = Sections.list_sections(household)
    care_items = CareItems.list_household_items(household)
    cards = build_cards(care_items, today)
    section_order = build_section_order(sections)
    section_cards = build_board_sections(sections, cards, filter, today)

    %Board{
      household: household,
      filter: filter,
      counts: build_board_counts(cards, today),
      sections: section_cards,
      needs_care_items: build_needs_care_items(cards, today, section_order)
    }
  end

  @spec build_board_counts([CareItemCard.t()], Date.t()) :: BoardCounts.t()
  defp build_board_counts(cards, %Date{} = today) do
    cards
    |> build_filter_counts(today)
    |> then(&struct!(BoardCounts, &1))
  end

  @spec build_board_sections([Section.t()], [CareItemCard.t()], Board.filter(), Date.t()) ::
          [BoardSection.t()]
  defp build_board_sections(sections, cards, :all, %Date{} = today) do
    Enum.map(sections, fn section ->
      items =
        cards
        |> Enum.filter(&(&1.item.section_id == section.id))
        |> sort_section_cards()

      build_section(section, items, today)
    end)
  end

  defp build_board_sections(sections, cards, filter, %Date{} = today) do
    sections
    |> Enum.map(fn section ->
      items =
        cards
        |> Enum.filter(&(&1.item.section_id == section.id))
        |> Enum.filter(&card_matches_filter?(&1, filter, today))
        |> sort_section_cards()

      build_section(section, items, today)
    end)
    |> Enum.reject(&Enum.empty?(&1.items))
  end

  @spec build_section(Section.t(), [CareItemCard.t()], Date.t()) :: BoardSection.t()
  defp build_section(%Section{} = section, items, %Date{} = today) do
    %BoardSection{
      section: section,
      summary: build_section_summary(items, today),
      items: items
    }
  end

  @spec build_section_summary([CareItemCard.t()], Date.t()) :: BoardSectionSummary.t()
  defp build_section_summary(cards, %Date{} = today) do
    cards
    |> build_filter_counts(today)
    |> then(&struct!(BoardSectionSummary, &1))
  end

  @spec build_needs_care_items(
          [CareItemCard.t()],
          Date.t(),
          %{required(Section.id()) => non_neg_integer()}
        ) :: [CareItemCard.t()]
  # Keeps the urgent items across the household, different from "normal" filtering.
  defp build_needs_care_items(cards, %Date{} = today, section_order) do
    cards
    |> Enum.filter(&card_matches_filter?(&1, :today, today))
    |> Enum.sort_by(&needs_care_sort_key(&1, section_order))
  end

  @spec build_cards([CareItem.t()], Date.t()) :: [CareItemCard.t()]
  defp build_cards(care_items, %Date{} = today) do
    care_items
    |> Enum.map(&build_card(&1, today))
  end

  @spec build_card(CareItem.t(), Date.t()) :: CareItemCard.t()
  defp build_card(%CareItem{} = care_item, %Date{} = today),
    do: CareItemCard.from_item(care_item, today)

  @spec sort_section_cards([CareItemCard.t()]) :: [CareItemCard.t()]
  defp sort_section_cards(cards) do
    Enum.sort_by(cards, &{&1.item.position, &1.item.inserted_at})
  end

  @spec build_filter_counts([CareItemCard.t()], Date.t()) ::
          %{
            required(:today) => non_neg_integer(),
            required(:tomorrow) => non_neg_integer(),
            required(:overdue) => non_neg_integer()
          }
  defp build_filter_counts(cards, %Date{} = today) do
    %{
      today: Enum.count(cards, &card_matches_filter?(&1, :today, today)),
      tomorrow: Enum.count(cards, &card_matches_filter?(&1, :tomorrow, today)),
      overdue: Enum.count(cards, &card_matches_filter?(&1, :overdue, today))
    }
  end

  @spec card_matches_filter?(CareItemCard.t(), Board.filter(), Date.t()) ::
          boolean()
  defp card_matches_filter?(%CareItemCard{}, :all, %Date{}), do: true

  defp card_matches_filter?(%CareItemCard{status: :no_schedule}, :no_schedule, %Date{}), do: true
  defp card_matches_filter?(%CareItemCard{}, :no_schedule, %Date{}), do: false

  defp card_matches_filter?(%CareItemCard{status: :no_schedule}, :today, %Date{}), do: false

  defp card_matches_filter?(
         %CareItemCard{effective_due_on: %Date{} = due_on},
         :today,
         %Date{} = today
       ) do
    Date.compare(due_on, today) in [:lt, :eq]
  end

  defp card_matches_filter?(%CareItemCard{effective_due_on: nil}, :today, %Date{}), do: false
  defp card_matches_filter?(%CareItemCard{status: :no_schedule}, :tomorrow, %Date{}), do: false

  defp card_matches_filter?(
         %CareItemCard{effective_due_on: %Date{} = due_on},
         :tomorrow,
         %Date{} = today
       ) do
    Date.compare(due_on, Date.add(today, 1)) == :eq
  end

  defp card_matches_filter?(%CareItemCard{effective_due_on: nil}, :tomorrow, %Date{}), do: false
  defp card_matches_filter?(%CareItemCard{status: :no_schedule}, :overdue, %Date{}), do: false

  defp card_matches_filter?(
         %CareItemCard{effective_due_on: %Date{} = due_on},
         :overdue,
         %Date{} = today
       ) do
    Date.compare(due_on, today) == :lt
  end

  defp card_matches_filter?(%CareItemCard{effective_due_on: nil}, :overdue, %Date{}), do: false

  # Keeps stable order: overdue, earlier due dates, the section order, the in-section position
  @spec needs_care_sort_key(CareItemCard.t(), %{required(Section.id()) => non_neg_integer()}) ::
          {non_neg_integer(), Date.t(), non_neg_integer(), non_neg_integer(), DateTime.t() | nil}
  defp needs_care_sort_key(%CareItemCard{} = card, section_order) do
    {
      status_priority(card.status),
      card.effective_due_on,
      Map.get(section_order, card.item.section_id, 0),
      card.item.position,
      card.item.inserted_at
    }
  end

  @spec status_priority(Schedule.status()) :: non_neg_integer()
  defp status_priority(:overdue), do: 0
  defp status_priority(:due_today), do: 1
  defp status_priority(:manually_flagged), do: 2
  defp status_priority(:soon), do: 3
  defp status_priority(:normal), do: 4
  defp status_priority(:no_schedule), do: 5

  @spec build_section_order([Section.t()]) :: %{required(Section.id()) => non_neg_integer()}
  defp build_section_order(sections) do
    sections
    |> Enum.with_index()
    |> Map.new(fn {%Section{id: section_id}, index} -> {section_id, index} end)
  end
end
