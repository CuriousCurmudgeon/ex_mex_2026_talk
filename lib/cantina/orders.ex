defmodule Cantina.Orders do
  @moduledoc """
  Places an order and splits it into one ticket for each station. Tracks when each order
  is complete. Marks an order served.
  """

  use GenServer

  alias Cantina.{Kitchen, LineItem, Menu, Ticket}

  @type status :: :placed | :ready | :served

  @type order :: %{
          id: String.t(),
          table_id: String.t(),
          line_items: [LineItem.t()],
          stations: %{Cantina.MenuItem.station() => :cooking | :ready},
          status: status(),
          placed_at: DateTime.t()
        }

  def start_link(_opts), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)

  @doc """
  Places an order for a table. `quantities` maps a menu item id to its quantity.

  Returns `{:error, :empty}` when no item has a quantity above zero.
  """
  def place(table_id, quantities) when is_binary(table_id) and is_map(quantities),
    do: GenServer.call(__MODULE__, {:place, table_id, quantities})

  @doc "Marks a complete order served. The expediter ran it to the table."
  def serve(order_id), do: GenServer.call(__MODULE__, {:serve, order_id})

  def get_order(order_id), do: GenServer.call(__MODULE__, {:get, order_id})

  @doc "The orders of one table, newest first."
  def list_orders(table_id), do: GenServer.call(__MODULE__, {:list_table, table_id})

  @doc "Each order that is not served yet, oldest first."
  def list_open_orders, do: GenServer.call(__MODULE__, :list_open)

  @doc "The last `count` orders, newest first."
  def recent_orders(count \\ 10), do: GenServer.call(__MODULE__, {:recent, count})

  @doc false
  # Cantina.Kitchen calls this after it bumps a ticket.
  def ticket_ready(%Ticket{} = ticket), do: GenServer.cast(__MODULE__, {:ticket_ready, ticket})

  ## Server

  @impl true
  def init(:ok), do: {:ok, %{orders: %{}}}

  @impl true
  def handle_call({:place, table_id, quantities}, _from, state) do
    case build_line_items(quantities) do
      [] ->
        {:reply, {:error, :empty}, state}

      line_items ->
        order_id = new_id("o")
        now = DateTime.utc_now()

        tickets =
          line_items
          |> Enum.group_by(fn {station, _item} -> station end, fn {_station, item} -> item end)
          |> Enum.map(fn {station, items} ->
            %Ticket{
              id: new_id("t"),
              order_id: order_id,
              table_id: table_id,
              station: station,
              line_items: items,
              fired_at: now
            }
          end)

        line_items = Enum.map(line_items, fn {_station, item} -> item end)

        order = %{
          id: order_id,
          table_id: table_id,
          line_items: line_items,
          stations: Map.new(tickets, &{&1.station, :cooking}),
          status: :placed,
          placed_at: now
        }

        for ticket <- tickets do
          :ok = Kitchen.open(ticket)
          Cantina.PubSub.broadcast_fired(ticket)
        end

        Cantina.PubSub.broadcast_placed(table_id, order_id, line_items)

        {:reply, {:ok, order}, put_in(state.orders[order_id], order)}
    end
  end

  def handle_call({:serve, order_id}, _from, state) do
    case Map.fetch(state.orders, order_id) do
      {:ok, %{status: :ready} = order} ->
        order = %{order | status: :served}
        Cantina.PubSub.broadcast_served(order.table_id, order_id)
        {:reply, {:ok, order}, put_in(state.orders[order_id], order)}

      {:ok, _order} ->
        {:reply, {:error, :not_ready}, state}

      :error ->
        {:reply, {:error, :not_found}, state}
    end
  end

  def handle_call({:get, order_id}, _from, state),
    do: {:reply, Map.get(state.orders, order_id), state}

  def handle_call({:list_table, table_id}, _from, state) do
    orders =
      state.orders
      |> Map.values()
      |> Enum.filter(&(&1.table_id == table_id))
      |> Enum.sort_by(& &1.placed_at, {:desc, DateTime})

    {:reply, orders, state}
  end

  def handle_call(:list_open, _from, state) do
    orders =
      state.orders
      |> Map.values()
      |> Enum.reject(&(&1.status == :served))
      |> Enum.sort_by(& &1.placed_at, DateTime)

    {:reply, orders, state}
  end

  def handle_call({:recent, count}, _from, state) do
    orders =
      state.orders
      |> Map.values()
      |> Enum.sort_by(& &1.placed_at, {:desc, DateTime})
      |> Enum.take(count)

    {:reply, orders, state}
  end

  @impl true
  def handle_cast({:ticket_ready, %Ticket{order_id: order_id, station: station}}, state) do
    case Map.fetch(state.orders, order_id) do
      {:ok, %{status: :placed} = order} ->
        order = put_in(order.stations[station], :ready)
        {:noreply, put_in(state.orders[order_id], maybe_complete(order))}

      _ ->
        {:noreply, state}
    end
  end

  defp maybe_complete(order) do
    if Enum.all?(order.stations, fn {_station, status} -> status == :ready end) do
      Cantina.PubSub.broadcast_order_complete(order.id, order.table_id)
      Cantina.PubSub.broadcast_ready(order.table_id, order.id)
      %{order | status: :ready}
    else
      order
    end
  end

  # Returns {station, line_item} pairs in menu order. Skips unknown items and zero
  # quantities.
  defp build_line_items(quantities) do
    Enum.flat_map(Menu.list_items(), fn item ->
      case quantity(quantities[item.id]) do
        quantity when quantity > 0 ->
          [{item.station, %LineItem{menu_item_id: item.id, name: item.name, quantity: quantity}}]

        _ ->
          []
      end
    end)
  end

  defp quantity(n) when is_integer(n), do: n

  defp quantity(n) when is_binary(n) do
    case Integer.parse(n) do
      {n, ""} -> n
      _ -> 0
    end
  end

  defp quantity(_), do: 0

  defp new_id(prefix),
    do: prefix <> "-" <> Integer.to_string(System.unique_integer([:positive, :monotonic]))
end
