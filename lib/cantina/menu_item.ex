defmodule Cantina.MenuItem do
  @moduledoc "One item on the menu. `station` is the kitchen station that cooks it."

  @type station :: :grill | :fryer | :bar

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          station: station(),
          price_cents: non_neg_integer(),
          available?: boolean()
        }

  @enforce_keys [:id, :name, :station, :price_cents]
  defstruct [:id, :name, :station, :price_cents, available?: true]
end
