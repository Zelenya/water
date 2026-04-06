defmodule Water.Garden.Attrs do
  @moduledoc false

  @spec has_attr?(map(), atom()) :: boolean()
  def has_attr?(attrs, key) do
    Map.has_key?(attrs, key) or Map.has_key?(attrs, Atom.to_string(key))
  end

  @spec get_attr(map(), atom()) :: nil | term()
  def get_attr(attrs, key) do
    case Map.fetch(attrs, key) do
      {:ok, current_value} ->
        current_value

      :error ->
        Map.get(attrs, Atom.to_string(key))
    end
  end

  @spec put_attr(map(), atom(), term()) :: map()
  def put_attr(attrs, key, value) do
    if prefers_string_keys?(attrs) do
      Map.put(attrs, Atom.to_string(key), value)
    else
      Map.put(attrs, key, value)
    end
  end

  @spec delete_attr(map(), atom()) :: map()
  def delete_attr(attrs, key) do
    attrs
    |> Map.delete(key)
    |> Map.delete(Atom.to_string(key))
  end

  @spec prefers_string_keys?(map()) :: boolean()
  def prefers_string_keys?(attrs) do
    Enum.any?(Map.keys(attrs), &is_binary/1) and not Enum.any?(Map.keys(attrs), &is_atom/1)
  end
end
