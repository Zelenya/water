defmodule Water.Households do
  @moduledoc """
  Household and member boundary.

  Currently, we are modelling around a single active (default) household.
  This context owns the setup and identity logic and can be extended later.
  """

  import Ecto.Query, warn: false

  alias Water.Households.{Household, Member}
  alias Water.Repo

  @type result(value) :: {:ok, value} | {:error, Ecto.Changeset.t()}

  @default_household_slug "default"
  @default_household_name "Water House"
  @default_household_timezone "America/Los_Angeles"

  @spec get_default_household!() :: Household.t()
  @doc """
  Returns the singleton household used today.
  """
  def get_default_household! do
    Repo.get_by!(Household, slug: @default_household_slug)
  end

  @spec bootstrap_default_household() :: result(Household.t())
  @doc """
  Creates the singleton household if it does not already exist.
  The function is idempotent on purpose for the seeds and setup.
  """
  def bootstrap_default_household do
    case Repo.get_by(Household, slug: @default_household_slug) do
      %Household{} = household ->
        {:ok, household}

      nil ->
        %Household{}
        |> Household.changeset(default_household_attrs())
        |> Repo.insert()
    end
  end

  @spec list_members(Household.t()) :: [Member.t()]
  def list_members(%Household{id: household_id}) do
    from(member in Member,
      where: member.household_id == ^household_id
    )
    |> Repo.all()
  end

  @spec create_member(Household.t(), map()) :: result(Member.t())
  def create_member(%Household{} = household, attrs) when is_map(attrs) do
    %Member{}
    |> Member.create_changeset(household, attrs)
    |> Repo.insert()
  end

  @spec update_member(Member.t(), map()) :: result(Member.t())
  def update_member(%Member{} = member, attrs) when is_map(attrs) do
    member
    |> Member.update_changeset(attrs)
    |> Repo.update()
  end

  @spec find_active_member_by_name(Household.t(), String.t()) :: nil | Member.t()
  def find_active_member_by_name(%Household{id: household_id}, raw_name)
      when is_binary(raw_name) do
    case normalize_member_name(raw_name) do
      "" ->
        nil

      normalized_name ->
        # Browser auth uses member names as the human-facing credential.
        # We normalize the incoming username to match the case-insensitive db uniqueness.
        from(member in Member,
          where:
            member.household_id == ^household_id and member.active == true and
              fragment("lower(btrim(?))", member.name) == ^normalized_name
        )
        |> Repo.one()
    end
  end

  def find_active_member_by_name(%Household{}, _), do: nil

  @spec default_household_attrs() :: %{
          name: String.t(),
          slug: String.t(),
          timezone: String.t()
        }
  defp default_household_attrs do
    %{
      name: @default_household_name,
      slug: @default_household_slug,
      timezone: @default_household_timezone
    }
  end

  @spec normalize_member_name(String.t()) :: String.t()
  defp normalize_member_name(raw_name) do
    raw_name
    |> String.trim()
    |> String.downcase()
  end
end
