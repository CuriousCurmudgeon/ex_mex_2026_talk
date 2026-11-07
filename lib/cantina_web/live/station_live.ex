defmodule CantinaWeb.StationLive do
  @moduledoc """
  The kitchen display of one station. A cook claims a ticket, cooks it, and bumps it.
  """

  use CantinaWeb, :live_view

  alias Cantina.{Kitchen, Menu, Presence}
  alias CantinaWeb.Format

  @impl true
  def mount(%{"station" => station_param} = params, _session, socket) do
    with {:ok, station} <- Menu.parse_station(station_param),
         name when is_binary(name) and name != "" <- params["name"] do
      mount_station(socket, station, String.slice(name, 0, 24))
    else
      _ -> {:ok, push_navigate(socket, to: ~p"/")}
    end
  end

  defp mount_station(socket, station, name) do
    if connected?(socket) and Presence.cook_counts()[station] >= Presence.max_cooks() do
      {:ok,
       socket
       |> put_flash(:error, "The #{Format.station_name(station)} is full. Pick another job.")
       |> push_navigate(to: ~p"/")}
    else
      if connected?(socket) do
        :ok = Cantina.PubSub.subscribe_station(station)
        :ok = Cantina.PubSub.subscribe_menu()
        {:ok, _ref} = Presence.track_cook(self(), station, name)
        :timer.send_interval(1_000, :tick)
      end

      {:ok,
       socket
       |> assign(:page_title, Format.station_name(station))
       |> assign(:station, station)
       |> assign(:cook_name, name)
       |> assign(:now, DateTime.utc_now())
       |> assign(:tickets, Kitchen.list_tickets(station))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} title={Format.station_label(@station)} wide>
      <:actions>
        <span class="text-sm text-base-content/70">
          Cooking as <span class="font-bold text-base-content">{@cook_name}</span>
        </span>
        <.link navigate={~p"/"} class="text-sm underline">Leave</.link>
      </:actions>

      <p :if={@tickets == []} class="py-24 text-center text-2xl text-base-content/40">
        No tickets. Wipe down the station. 🧽
      </p>

      <div id="tickets" class="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <.ticket
          :for={ticket <- @tickets}
          ticket={ticket}
          age={Format.age(ticket.fired_at, @now)}
          cook_name={@cook_name}
        />
      </div>
    </Layouts.app>
    """
  end

  attr :ticket, Cantina.Ticket, required: true
  attr :age, :integer, required: true
  attr :cook_name, :string, required: true

  defp ticket(assigns) do
    ~H"""
    <article
      id={"ticket-#{@ticket.id}"}
      class={[
        "flex flex-col rounded-2xl border-t-8 bg-base-200 p-4 shadow transition-colors",
        heat_class(@age)
      ]}
    >
      <header class="flex items-baseline justify-between">
        <span class="text-lg font-black">Table {@ticket.table_id}</span>
        <span class="font-mono tabular-nums text-base-content/70">{Format.clock(@age)}</span>
      </header>
      <ul class="my-3 flex-1 space-y-1">
        <li :for={item <- @ticket.line_items} class="text-lg">
          <span class="font-bold">{item.quantity}×</span> {item.name}
        </li>
      </ul>
      <%= cond do %>
        <% @ticket.claimed_by == nil -> %>
          <button
            phx-click="claim"
            phx-value-id={@ticket.id}
            class="rounded-xl bg-amber-500 py-3 font-black text-black transition hover:bg-amber-400 active:scale-95"
          >
            Claim
          </button>
        <% @ticket.claimed_by == @cook_name -> %>
          <button
            phx-click="bump"
            phx-value-id={@ticket.id}
            class="rounded-xl bg-emerald-500 py-3 font-black text-black transition hover:bg-emerald-400 active:scale-95"
          >
            Bump
          </button>
        <% true -> %>
          <p class="rounded-xl bg-base-300 py-3 text-center font-semibold text-base-content/60">
            Taken by {@ticket.claimed_by}
          </p>
      <% end %>
    </article>
    """
  end

  defp heat_class(age) when age >= 40, do: "border-rose-500"
  defp heat_class(age) when age >= 20, do: "border-yellow-400"
  defp heat_class(_age), do: "border-emerald-500"

  @impl true
  def handle_event("claim", %{"id" => id}, socket) do
    %{station: station, cook_name: name} = socket.assigns

    case Kitchen.claim(station, id, name) do
      {:ok, ticket} -> {:noreply, put_ticket(socket, ticket)}
      {:error, :taken} -> {:noreply, put_flash(socket, :error, "Another cook got there first.")}
      {:error, :not_found} -> {:noreply, drop_ticket(socket, id)}
    end
  end

  def handle_event("bump", %{"id" => id}, socket) do
    %{station: station, cook_name: name} = socket.assigns

    case Kitchen.bump(station, id, name) do
      # Kitchen.bump/3 skips this process when it broadcasts, so drop the card here.
      {:ok, _ticket} -> {:noreply, drop_ticket(socket, id)}
      {:error, :not_yours} -> {:noreply, put_flash(socket, :error, "That ticket is not yours.")}
      {:error, :not_found} -> {:noreply, drop_ticket(socket, id)}
    end
  end

  @impl true
  def handle_info(:tick, socket), do: {:noreply, assign(socket, :now, DateTime.utc_now())}

  def handle_info({:ticket_fired, %{ticket: ticket}}, socket),
    do: {:noreply, put_ticket(socket, ticket)}

  def handle_info({:ticket_claimed, %{ticket_id: id, cook_name: name}}, socket),
    do: {:noreply, update_ticket(socket, id, &%{&1 | claimed_by: name})}

  def handle_info({:ticket_released, %{ticket_id: id}}, socket),
    do: {:noreply, update_ticket(socket, id, &%{&1 | claimed_by: nil})}

  def handle_info({:ticket_bumped, %{ticket_id: id}}, socket),
    do: {:noreply, drop_ticket(socket, id)}

  def handle_info({:special_added, %{item: item}}, socket) do
    if item.station == socket.assigns.station do
      {:noreply, put_flash(socket, :info, "New special: #{item.name}")}
    else
      {:noreply, socket}
    end
  end

  defp put_ticket(socket, ticket) do
    update(socket, :tickets, fn tickets ->
      if Enum.any?(tickets, &(&1.id == ticket.id)) do
        Enum.map(tickets, &if(&1.id == ticket.id, do: ticket, else: &1))
      else
        tickets ++ [ticket]
      end
    end)
  end

  defp update_ticket(socket, id, fun) do
    update(socket, :tickets, fn tickets ->
      Enum.map(tickets, &if(&1.id == id, do: fun.(&1), else: &1))
    end)
  end

  defp drop_ticket(socket, id),
    do: update(socket, :tickets, &Enum.reject(&1, fn t -> t.id == id end))
end
