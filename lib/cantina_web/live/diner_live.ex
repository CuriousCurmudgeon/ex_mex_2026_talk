defmodule CantinaWeb.DinerLive do
  @moduledoc "A diner orders food from a phone and follows each order."

  use CantinaWeb, :live_view

  alias Cantina.{Menu, Orders, Presence}
  alias CantinaWeb.Format

  @impl true
  def mount(%{"table_id" => table_id}, _session, socket) do
    if connected?(socket) do
      :ok = Cantina.PubSub.subscribe_table(table_id)
      :ok = Cantina.PubSub.subscribe_menu()
      {:ok, _ref} = Presence.track_diner(self(), table_id)
    end

    {:ok,
     socket
     |> assign(:page_title, "Table #{table_id}")
     |> assign(:table_id, table_id)
     |> assign(:menu, Menu.list_items())
     |> assign(:quantities, %{})
     |> assign(:orders, Orders.list_orders(table_id) |> Enum.map(&order_view/1))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} title={"Table #{@table_id}"}>
      <section :for={station <- Menu.stations()} class="space-y-2">
        <h2 class="text-sm font-bold uppercase tracking-widest text-base-content/60">
          {Format.station_label(station)}
        </h2>
        <ul class="divide-y divide-base-300 rounded-2xl border border-base-300 bg-base-200/40">
          <li
            :for={item <- Enum.filter(@menu, &(&1.station == station))}
            id={"item-#{item.id}"}
            class={[
              "flex items-center justify-between gap-3 px-4 py-3",
              !item.available? && "opacity-40"
            ]}
          >
            <div>
              <p class="font-semibold">{item.name}</p>
              <p class="text-sm text-base-content/60">{Format.price(item.price_cents)}</p>
            </div>
            <div class="flex items-center gap-2">
              <button
                phx-click="decrement"
                phx-value-id={item.id}
                disabled={!item.available? || Map.get(@quantities, item.id, 0) == 0}
                class="size-9 rounded-full border border-base-300 text-lg font-bold transition hover:bg-base-300 disabled:opacity-30"
                aria-label={"Fewer #{item.name}"}
              >
                −
              </button>
              <span class="w-6 text-center font-mono text-lg tabular-nums">
                {Map.get(@quantities, item.id, 0)}
              </span>
              <button
                phx-click="increment"
                phx-value-id={item.id}
                disabled={!item.available?}
                class="size-9 rounded-full bg-amber-500 text-lg font-bold text-black transition hover:bg-amber-400 active:scale-95 disabled:opacity-30"
                aria-label={"More #{item.name}"}
              >
                +
              </button>
            </div>
          </li>
        </ul>
      </section>

      <button
        id="place-order"
        phx-click="place"
        disabled={item_count(@quantities) == 0}
        class="sticky bottom-4 w-full rounded-2xl bg-emerald-500 py-4 text-lg font-black text-black shadow-lg transition hover:bg-emerald-400 active:scale-[0.99] disabled:bg-base-300 disabled:text-base-content/40"
      >
        <%= if item_count(@quantities) == 0 do %>
          Pick something tasty
        <% else %>
          Order {item_count(@quantities)} {if item_count(@quantities) == 1, do: "item", else: "items"} · {Format.price(
            total(@menu, @quantities)
          )}
        <% end %>
      </button>

      <section :if={@orders != []} class="space-y-2">
        <h2 class="text-sm font-bold uppercase tracking-widest text-base-content/60">
          Your orders
        </h2>
        <ul id="orders" class="space-y-2">
          <li
            :for={order <- @orders}
            id={"order-#{order.id}"}
            class="rounded-2xl border border-base-300 px-4 py-3"
          >
            <div class="flex items-center justify-between">
              <p class="text-sm text-base-content/70">
                {Enum.map_join(order.line_items, ", ", &"#{&1.quantity}× #{&1.name}")}
              </p>
              <.status status={order.status} />
            </div>
          </li>
        </ul>
      </section>
    </Layouts.app>
    """
  end

  attr :status, :atom, required: true

  defp status(assigns) do
    ~H"""
    <span class={[
      "shrink-0 rounded-full px-3 py-1 text-xs font-bold uppercase tracking-wide",
      @status == :placed && "bg-amber-500/20 text-amber-500",
      @status == :ready && "animate-pulse bg-emerald-500/20 text-emerald-500",
      @status == :served && "bg-base-300 text-base-content/60"
    ]}>
      {case @status do
        :placed -> "In the kitchen"
        :ready -> "Ready"
        :served -> "Served"
      end}
    </span>
    """
  end

  @impl true
  def handle_event("increment", %{"id" => id}, socket) do
    {:noreply, update(socket, :quantities, &Map.update(&1, id, 1, fn n -> n + 1 end))}
  end

  def handle_event("decrement", %{"id" => id}, socket) do
    {:noreply, update(socket, :quantities, &Map.update(&1, id, 0, fn n -> max(n - 1, 0) end))}
  end

  def handle_event("place", _params, socket) do
    case Orders.place(socket.assigns.table_id, socket.assigns.quantities) do
      {:ok, _order} ->
        {:noreply,
         socket |> assign(:quantities, %{}) |> put_flash(:info, "Order sent to the kitchen!")}

      {:error, :empty} ->
        {:noreply, put_flash(socket, :error, "Pick at least one item.")}
    end
  end

  @impl true
  def handle_info({:placed, %{order_id: id, line_items: line_items}}, socket) do
    order = %{id: id, line_items: line_items, status: :placed}
    {:noreply, update(socket, :orders, &upsert(&1, order))}
  end

  def handle_info({:ready, %{order_id: id}}, socket),
    do: {:noreply, set_status(socket, id, :ready)}

  def handle_info({:served, %{order_id: id}}, socket),
    do: {:noreply, set_status(socket, id, :served)}

  def handle_info({:special_added, %{item: item}}, socket),
    do: {:noreply, update(socket, :menu, &(&1 ++ [item]))}

  defp order_view(order), do: Map.take(order, [:id, :line_items, :status])

  defp upsert(orders, order) do
    if Enum.any?(orders, &(&1.id == order.id)), do: orders, else: [order | orders]
  end

  defp set_status(socket, id, status) do
    update(socket, :orders, fn orders ->
      Enum.map(orders, &if(&1.id == id, do: %{&1 | status: status}, else: &1))
    end)
  end

  defp item_count(quantities), do: quantities |> Map.values() |> Enum.sum()

  defp total(menu, quantities) do
    Enum.reduce(menu, 0, &(&2 + &1.price_cents * Map.get(quantities, &1.id, 0)))
  end
end
