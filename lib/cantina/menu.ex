defmodule Cantina.Menu do
  @moduledoc "Holds the menu in an `Agent`. Adds a special during service."

  use Agent

  alias Cantina.MenuItem

  @stations [:grill, :fryer, :bar]

  @items [
    {:grill, "carne-asada-tacos", "Carne asada tacos", 1250},
    {:grill, "al-pastor-tacos", "Al pastor tacos", 1150},
    {:grill, "chicken-fajitas", "Chicken fajitas", 1600},
    {:grill, "cheese-quesadilla", "Cheese quesadilla", 900},
    {:fryer, "chips-and-guac", "Chips and guac", 800},
    {:fryer, "chips-and-queso", "Chips and queso", 750},
    {:fryer, "flautas", "Flautas", 1000},
    {:fryer, "churros", "Churros", 650},
    {:bar, "margarita", "Margarita", 1100},
    {:bar, "horchata", "Horchata", 450},
    {:bar, "mexican-coke", "Mexican Coke", 400},
    {:bar, "agua-fresca", "Agua fresca", 450}
  ]

  def start_link(_opts) do
    Agent.start_link(&initial_items/0, name: __MODULE__)
  end

  @doc "The stations of the kitchen, in order."
  def stations, do: @stations

  @doc "Parses a station from a URL. Returns `:error` for an unknown station."
  def parse_station(station) when is_binary(station) do
    Enum.find_value(@stations, :error, &(Atom.to_string(&1) == station && {:ok, &1}))
  end

  @doc "Each item on the menu, in menu order."
  def list_items, do: Agent.get(__MODULE__, & &1)

  def get_item(id), do: Agent.get(__MODULE__, fn items -> Enum.find(items, &(&1.id == id)) end)

  @doc """
  Adds a special to the menu and tells each screen.

  `attrs` has `:name`, `:station`, and `:price_cents`.
  """
  def add_special(attrs, note \\ nil) do
    with {:ok, item} <- build_special(attrs) do
      Agent.update(__MODULE__, &(&1 ++ [item]))
      :ok = Phoenix.PubSub.broadcast(Cantina.PubSub, "menu", {:special, item, note})
      {:ok, item}
    end
  end

  defp build_special(%{name: name, station: station, price_cents: price})
       when is_binary(name) and name != "" and station in @stations and is_integer(price) and
              price >= 0 do
    id = "special-" <> Integer.to_string(System.unique_integer([:positive]))
    {:ok, %MenuItem{id: id, name: name, station: station, price_cents: price}}
  end

  defp build_special(_attrs), do: {:error, :invalid}

  defp initial_items do
    for {station, id, name, price} <- @items do
      %MenuItem{id: id, name: name, station: station, price_cents: price}
    end
  end
end
