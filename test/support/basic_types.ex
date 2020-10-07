defmodule BasicTypes do
  @moduledoc """
  A good-enough-for-tests implementation for typeof. Useful when you do not care
  what the exact type is, but to just compare different types.
  """

  def typeof(self) do
    cond do
      is_float(self) -> "float"
      is_number(self) -> "number"
      is_atom(self) -> "atom"
      is_boolean(self) -> "boolean"
      is_binary(self) -> "binary"
      is_function(self) -> "function"
      is_list(self) -> "list"
      is_tuple(self) -> "tuple"
      true -> "other"
    end
  end
end
