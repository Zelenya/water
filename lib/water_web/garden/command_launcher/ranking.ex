defmodule WaterWeb.Garden.CommandLauncher.Ranking do
  @moduledoc false

  alias Water.Garden.Schedule
  alias WaterWeb.Garden.CommandLauncher.Entry

  @type rank() :: :nomatch | non_neg_integer()

  @spec normalize_text(String.t()) :: String.t()
  def normalize_text(value) do
    value
    |> String.trim()
    |> String.downcase()
  end

  @spec matching_entries(
          [Entry.t()],
          String.t(),
          (Entry.t() -> [String.t()]),
          ({Entry.t(), non_neg_integer()} -> term())
        ) :: [Entry.t()]
  def matching_entries(entries, query, terms_fun, sort_key_fun) do
    entries
    |> Enum.map(fn entry -> {entry, rank_terms(terms_fun.(entry), query)} end)
    |> Enum.filter(fn {_, rank} -> rank != :nomatch end)
    |> Enum.sort_by(sort_key_fun)
    |> Enum.map(&elem(&1, 0))
  end

  @spec command_sort_key({Entry.t(), non_neg_integer()}) :: {non_neg_integer(), String.t()}
  def command_sort_key({%Entry{} = entry, rank}) do
    {rank, String.downcase(entry.title)}
  end

  @spec item_sort_key({Entry.t(), non_neg_integer()}) ::
          {non_neg_integer(), non_neg_integer(), String.t()}
  def item_sort_key({%Entry{} = entry, rank}) do
    {rank, urgency_rank(entry.status), String.downcase(entry.title)}
  end

  @spec cap_group([Entry.t()], Entry.group(), pos_integer()) :: [Entry.t()]
  def cap_group(results, group, cap) do
    {_count, kept} =
      Enum.reduce(results, {0, []}, fn entry, {count, acc} ->
        cond do
          entry.group != group ->
            {count, [entry | acc]}

          count < cap ->
            {count + 1, [entry | acc]}

          true ->
            {count, acc}
        end
      end)

    Enum.reverse(kept)
  end

  @spec rank_terms([String.t()], String.t()) :: rank()
  # Exact match > Prefix match > Substring match
  # TODO: Fuzzy search
  defp rank_terms(terms, query) do
    terms
    |> Enum.map(&normalize_text/1)
    |> Enum.reduce(:nomatch, fn term, best_rank ->
      term_rank =
        cond do
          term == query -> 0
          String.starts_with?(term, query) -> 1
          String.contains?(term, query) -> 2
          true -> :nomatch
        end

      min_rank(best_rank, term_rank)
    end)
  end

  @spec min_rank(rank(), rank()) :: rank()
  defp min_rank(:nomatch, right), do: right
  defp min_rank(left, :nomatch), do: left
  defp min_rank(left, right), do: min(left, right)

  @spec urgency_rank(nil | Schedule.status()) :: non_neg_integer()
  defp urgency_rank(:overdue), do: 0
  defp urgency_rank(:due_today), do: 1
  defp urgency_rank(:soon), do: 2
  defp urgency_rank(:manually_flagged), do: 3
  defp urgency_rank(:normal), do: 4
  defp urgency_rank(:no_schedule), do: 5
  defp urgency_rank(nil), do: 6
end
