defmodule CustomStruct do
  defstruct [:value]

  defimpl Poison.Encoder do
    def encode(struct, opts) do
      Poison.Encoder.encode(struct.value, opts)
    end
  end
end
