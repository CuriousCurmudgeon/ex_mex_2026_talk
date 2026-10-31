defmodule Cantina.Ticket do
  @moduledoc "The list of items that one station cooks for one order."

  @type t :: %__MODULE__{
          id: String.t(),
          order_id: String.t(),
          table_id: String.t(),
          station: Cantina.MenuItem.station(),
          line_items: [Cantina.LineItem.t()],
          fired_at: DateTime.t(),
          claimed_by: String.t() | nil
        }

  @enforce_keys [:id, :order_id, :table_id, :station, :line_items, :fired_at]
  defstruct [:id, :order_id, :table_id, :station, :line_items, :fired_at, :claimed_by]
end
