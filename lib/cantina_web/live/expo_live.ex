defmodule CantinaWeb.ExpoLive do
  @moduledoc """
  The expediter collects the tickets of each order at the pass and runs the complete order.
  """

  use CantinaWeb, :live_view

  alias Cantina.Orders
  alias CantinaWeb.Format

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: :ok = Cantina.PubSub.subscribe_expo()

    {:ok,
     socket
     |> assign(:page_title, "Expo")
     |> assign(:orders, Orders.list_open_orders())}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} title="Expo · the pass" wide>
      <p :if={@orders == []} class="py-24 text-center text-2xl text-base-content/40">
        The pass is clear.
      </p>

      <div id="orders" class="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <article
          :for={order <- @orders}
          id={"order-#{order.id}"}
          class={[
            "flex flex-col rounded-2xl border-2 bg-base-200 p-4 transition",
            if(order.status == :ready, do: "border-emerald-500 shadow-lg", else: "border-base-300")
          ]}
        >
          <header class="text-lg font-black">Table {order.table_id}</header>
          <ul class="my-3 flex-1 space-y-1">
            <li :for={{station, status} <- order.stations} class="flex items-center gap-2">
              <span class={[
                "flex size-6 items-center justify-center rounded-full text-sm",
                if(status == :ready,
                  do: "bg-emerald-500 text-black",
                  else: "border border-base-content/30"
                )
              ]}>
                {if status == :ready, do: "✓"}
              </span>
              {Format.station_label(station)}
            </li>
          </ul>
          <button
            :if={order.status == :ready}
            phx-click="run"
            phx-value-id={order.id}
            class="rounded-xl bg-emerald-500 py-3 font-black text-black transition hover:bg-emerald-400 active:scale-95"
          >
            Run it
          </button>
        </article>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("run", %{"id" => id}, socket) do
    case Orders.serve(id) do
      {:ok, _order} -> {:noreply, drop_order(socket, id)}
      {:error, :not_ready} -> {:noreply, put_flash(socket, :error, "That order is not complete.")}
      {:error, :not_found} -> {:noreply, drop_order(socket, id)}
    end
  end

  @impl true
  def handle_info({:ticket_ready, %{ticket: ticket}}, socket) do
    socket =
      if Enum.any?(socket.assigns.orders, &(&1.id == ticket.order_id)) do
        socket
      else
        # The first ticket of an order brings its card to the pass.
        case Orders.get_order(ticket.order_id) do
          nil -> socket
          order -> update(socket, :orders, &(&1 ++ [order]))
        end
      end

    {:noreply,
     update_order(socket, ticket.order_id, &put_in(&1.stations[ticket.station], :ready))}
  end

  def handle_info({:order_complete, %{order_id: id}}, socket) do
    {:noreply, update_order(socket, id, &%{&1 | status: :ready})}
  end

  defp update_order(socket, id, fun) do
    update(socket, :orders, fn orders ->
      Enum.map(orders, &if(&1.id == id, do: fun.(&1), else: &1))
    end)
  end

  defp drop_order(socket, id),
    do: update(socket, :orders, &Enum.reject(&1, fn o -> o.id == id end))
end
