defmodule Water.Garden.Sections do
  import Ecto.Query, warn: false

  alias Water.Garden.{Attrs, Section}
  alias Water.Households.Household
  alias Water.Repo

  @spec list_sections(Household.t()) :: [Section.t()]
  def list_sections(%Household{id: household_id}) do
    from(section in Section,
      where: section.household_id == ^household_id,
      order_by: [asc: section.position, asc: section.inserted_at]
    )
    |> Repo.all()
  end

  @spec create_section(Household.t(), map()) :: {:ok, Section.t()} | {:error, Ecto.Changeset.t()}
  def create_section(%Household{id: household_id} = household, attrs) when is_map(attrs) do
    attrs =
      maybe_put_default_attr(attrs, :position, next_section_position(household_id))

    %Section{}
    |> Section.create_changeset(household, attrs)
    |> Repo.insert()
  end

  @spec update_section(Section.t(), map()) :: {:ok, Section.t()} | {:error, Ecto.Changeset.t()}
  def update_section(%Section{} = section, attrs) when is_map(attrs) do
    section
    |> Section.update_changeset(attrs)
    |> Repo.update()
  end

  @spec next_section_position(Household.id()) :: non_neg_integer()
  defp next_section_position(household_id) do
    from(section in Section,
      where: section.household_id == ^household_id,
      select: max(section.position)
    )
    |> Repo.one()
    |> case do
      nil -> 0
      position -> position + 1
    end
  end

  @spec maybe_put_default_attr(map(), atom(), term()) :: map()
  defp maybe_put_default_attr(attrs, key, value) do
    case Attrs.has_attr?(attrs, key) do
      true -> attrs
      false -> Attrs.put_attr(attrs, key, value)
    end
  end
end
