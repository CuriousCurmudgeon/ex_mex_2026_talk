defmodule CantinaWeb.BoardLive do
  @moduledoc """
  The projector. It collects events from many topics into one screen.
  """

  use CantinaWeb, :live_view

  alias Cantina.{Kitchen, Menu, Orders, Presence, Rush}
  alias CantinaWeb.Format

  @feed_size 8

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Cantina.PubSub, "expo")
      Phoenix.PubSub.subscribe(Cantina.PubSub, "menu")

      for station <- Menu.stations(),
          do: Phoenix.PubSub.subscribe(Cantina.PubSub, "station:" <> to_string(station))

      Phoenix.PubSub.subscribe(Cantina.PubSub, "presence:diners")
      Phoenix.PubSub.subscribe(Cantina.PubSub, "presence:cooks")
    end

    {:ok,
     socket
     |> assign(:page_title, "Board")
     |> assign(:stats, Kitchen.stats())
     |> assign(:feed, Orders.recent_orders(@feed_size) |> Enum.map(&feed_entry/1))
     |> assign(:specials, [])
     |> assign(:rush?, Rush.running?())
     |> assign(:special_form, special_form())
     |> assign_presence()}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} title="Tonight's service" wide>
      <:actions>
        <button
          id="rush-toggle"
          phx-click="toggle_rush"
          class={[
            "rounded-xl px-4 py-2 font-black transition active:scale-95",
            if(@rush?,
              do: "bg-rose-500 text-white hover:bg-rose-400",
              else: "bg-amber-500 text-black hover:bg-amber-400"
            )
          ]}
        >
          {if @rush?, do: "Stop the rush", else: "Start the rush"}
        </button>
      </:actions>

      <p id="presence" class="text-center text-3xl font-black tracking-tight sm:text-5xl">
        {@diners} {if @diners == 1, do: "diner", else: "diners"} seated
        <span class="text-amber-500">·</span>
        {@cooks} {if @cooks == 1, do: "cook", else: "cooks"} on the line
      </p>

      <div class="grid gap-4 sm:grid-cols-3">
        <section
          :for={station <- Menu.stations()}
          id={"stats-#{station}"}
          class="rounded-2xl border border-base-300 bg-base-200/50 p-5"
        >
          <h2 class="text-2xl font-black">{Format.station_label(station)}</h2>
          <p class="mt-3 text-6xl font-black tabular-nums">{@stats[station].open}</p>
          <p class="text-sm uppercase tracking-widest text-base-content/60">open tickets</p>
          <p class="mt-3 text-base-content/70">
            avg cook time <span class="font-mono font-bold">{average(@stats[station])}</span>
          </p>
        </section>
      </div>

      <div class="grid gap-6 lg:grid-cols-3">
        <section class="lg:col-span-2">
          <h2 class="mb-2 text-sm font-bold uppercase tracking-widest text-base-content/60">
            Latest orders
          </h2>
          <ul id="feed" class="space-y-2">
            <li
              :for={entry <- @feed}
              id={"feed-#{entry.id}"}
              class="flex items-center justify-between gap-3 rounded-xl bg-base-200/60 px-4 py-2"
            >
              <span class="font-bold">Table {entry.table_id}</span>
              <span class="flex-1 truncate text-sm text-base-content/70">
                {Enum.map_join(entry.line_items, ", ", &"#{&1.quantity}× #{&1.name}")}
              </span>
              <.feed_status id={"feed-status-#{entry.id}"} status={entry.status} />
            </li>
          </ul>
        </section>

        <section class="space-y-3">
          <h2 class="text-sm font-bold uppercase tracking-widest text-base-content/60">
            Add a special
          </h2>
          <.form for={@special_form} id="special-form" phx-submit="add_special" class="space-y-1">
            <.input field={@special_form[:name]} label="Name" required />
            <.input
              field={@special_form[:station]}
              type="select"
              label="Station"
              options={Enum.map(Menu.stations(), &{Format.station_name(&1), &1})}
            />
            <.input field={@special_form[:price]} type="number" label="Price ($)" min="0" step="0.5" />
            <.input field={@special_form[:note]} label="Note (optional)" />
            <button class="w-full rounded-xl bg-amber-500 py-2 font-black text-black transition hover:bg-amber-400">
              Add special
            </button>
          </.form>
          <ul id="specials" class="space-y-1">
            <li :for={special <- @specials} class="text-sm">
              ⭐ <span class="font-bold">{special.item.name}</span>
              <span :if={special.note} class="text-base-content/60">— {special.note}</span>
            </li>
          </ul>
        </section>
      </div>
    </Layouts.app>
    """
  end

  attr :id, :string, required: true
  attr :status, :atom, required: true

  defp feed_status(%{status: :placed} = assigns), do: ~H""

  defp feed_status(assigns) do
    ~H"""
    <span
      id={@id}
      class={[
        "text-sm font-bold",
        if(@status == :ready, do: "text-emerald-500", else: "text-base-content/50")
      ]}
    >
      {if @status == :ready, do: "at the pass", else: "served"}
    </span>
    """
  end

  @impl true
  def handle_event("toggle_rush", _params, socket) do
    :ok = if socket.assigns.rush?, do: Rush.stop(), else: Rush.start()
    {:noreply, assign(socket, :rush?, Rush.running?())}
  end

  def handle_event("add_special", %{"name" => name, "station" => station} = params, socket) do
    attrs = %{
      name: String.trim(name),
      station: parse_station(station),
      price_cents: parse_price(params["price"])
    }

    note = if (n = String.trim(params["note"] || "")) != "", do: n

    case Menu.add_special(attrs, note) do
      {:ok, _item} ->
        {:noreply, assign(socket, :special_form, special_form())}

      {:error, :invalid} ->
        {:noreply, put_flash(socket, :error, "A special needs a name and a price.")}
    end
  end

  @impl true
  def handle_info({:fired, ticket}, socket) do
    {:noreply,
     socket
     |> update_stats(ticket.station, &%{&1 | open: &1.open + 1})
     |> update(:feed, &add_to_feed(&1, ticket))}
  end

  def handle_info(%{event: "bumped", station: station, cook_seconds: seconds}, socket) do
    {:noreply,
     update_stats(socket, station, fn stats ->
       %{
         stats
         | open: max(stats.open - 1, 0),
           bumped: stats.bumped + 1,
           total_seconds: stats.total_seconds + seconds
       }
     end)}
  end

  def handle_info({:order_complete, %{order_id: id}}, socket) do
    {:noreply, set_feed_status(socket, id, :ready)}
  end

  def handle_info({:special_added, item, note}, socket) do
    {:noreply, update(socket, :specials, &[%{item: item, note: note} | &1])}
  end

  def handle_info(%Phoenix.Socket.Broadcast{event: "presence_diff"}, socket) do
    {:noreply, assign_presence(socket)}
  end

  def handle_info(_, socket), do: {:noreply, socket}

  defp assign_presence(socket) do
    socket
    |> assign(:diners, Presence.diner_count())
    |> assign(:cooks, Presence.cook_counts() |> Map.values() |> Enum.sum())
  end

  defp update_stats(socket, station, fun) do
    update(socket, :stats, &Map.update!(&1, station, fun))
  end

  # The feed groups the fired tickets of one order into one entry.
  defp add_to_feed(feed, ticket) do
    if Enum.any?(feed, &(&1.id == ticket.order_id)) do
      Enum.map(feed, fn entry ->
        if entry.id == ticket.order_id,
          do: %{entry | line_items: entry.line_items ++ ticket.line_items},
          else: entry
      end)
    else
      entry = %{
        id: ticket.order_id,
        table_id: ticket.table_id,
        line_items: ticket.line_items,
        status: :placed
      }

      Enum.take([entry | feed], @feed_size)
    end
  end

  defp feed_entry(order) do
    %{
      id: order.id,
      table_id: order.table_id,
      line_items: order.line_items,
      status: order.status
    }
  end

  defp set_feed_status(socket, order_id, status) do
    update(socket, :feed, fn feed ->
      Enum.map(feed, &if(&1.id == order_id, do: %{&1 | status: status}, else: &1))
    end)
  end

  defp average(%{bumped: 0}), do: "—"
  defp average(%{bumped: n, total_seconds: total}), do: Format.clock(round(total / n))

  defp special_form,
    do: to_form(%{"name" => "", "station" => "grill", "price" => "", "note" => ""})

  defp parse_station(station) do
    case Menu.parse_station(station) do
      {:ok, station} -> station
      :error -> nil
    end
  end

  defp parse_price(price) do
    case Float.parse(price || "") do
      {dollars, _rest} when dollars >= 0 -> round(dollars * 100)
      _ -> nil
    end
  end
end
