defmodule CustomStruct do
  defstruct [:value]

  defimpl Jason.Encoder do
    def encode(struct, opts) do
      Jason.Encoder.encode(struct.value, opts)
    end
  end
end
