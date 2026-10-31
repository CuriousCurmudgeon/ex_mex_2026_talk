defmodule Cantina.LineItem do
  @moduledoc "One menu item of an order, with its quantity."

  @type t :: %__MODULE__{
          menu_item_id: String.t(),
          name: String.t(),
          quantity: pos_integer(),
          note: String.t() | nil
        }

  @enforce_keys [:menu_item_id, :name, :quantity]
  defstruct [:menu_item_id, :name, :quantity, :note]
end
