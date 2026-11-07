defmodule Cantina.Kitchen do
  @moduledoc """
  Holds the open tickets of each station. Claims, releases, and bumps a ticket.

  A ticket has at most one cook. The server monitors the LiveView process of each cook
  with a claim. When that process exits, the server releases each ticket of that cook. The
  server also bumps a ticket itself after `:auto_bump_ms`, claimed or not, so that a
  distracted volunteer does not stall the demo.
  """

  use GenServer

  alias Cantina.Ticket

  def start_link(_opts), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)

  @doc "Opens a ticket at its station. `Cantina.Orders` broadcasts `:fired`."
  def open(%Ticket{} = ticket), do: GenServer.call(__MODULE__, {:open, ticket})

  @doc "The open tickets of a station, oldest first."
  def list_tickets(station), do: GenServer.call(__MODULE__, {:list, station})

  @doc "The count of open tickets and the average of `cook_seconds` at each station."
  def stats, do: GenServer.call(__MODULE__, :stats)

  @doc "A name for a cook that did not give one, as \"Cook 3\"."
  def next_cook_name, do: GenServer.call(__MODULE__, :next_cook_name)

  @doc """
  The cook takes a ticket. The server monitors the calling process and releases the
  ticket when that process exits.
  """
  def claim(station, ticket_id, cook_name),
    do: GenServer.call(__MODULE__, {:claim, station, ticket_id, cook_name})

  @doc """
  Marks a ticket done. Only the cook that holds the ticket can bump it. The other screens
  of the station drop the card. The screen of the caller drops it itself.
  """
  def bump(station, ticket_id, cook_name),
    do: GenServer.call(__MODULE__, {:bump, station, ticket_id, cook_name})

  @doc "Bumps a ticket for the kitchen, with no cook. Each screen drops the card."
  def auto_bump(ticket_id), do: GenServer.call(__MODULE__, {:auto_bump, ticket_id})

  ## Server

  @impl true
  def init(:ok) do
    {:ok,
     %{
       tickets: %{},
       # ticket_id => pid of the cook that holds it
       holders: %{},
       # pid => monitor ref
       monitors: %{},
       # station => {count, total_seconds}
       bumps: %{},
       cook_number: 0
     }}
  end

  @impl true
  def handle_call({:open, ticket}, _from, state) do
    Process.send_after(self(), {:auto_bump, ticket.id}, auto_bump_ms())
    {:reply, :ok, put_in(state.tickets[ticket.id], ticket)}
  end

  def handle_call({:list, station}, _from, state) do
    tickets =
      state.tickets
      |> Map.values()
      |> Enum.filter(&(&1.station == station))
      |> Enum.sort_by(& &1.fired_at, DateTime)

    {:reply, tickets, state}
  end

  def handle_call(:stats, _from, state) do
    stats =
      Map.new(Cantina.Menu.stations(), fn station ->
        open = Enum.count(state.tickets, fn {_id, t} -> t.station == station end)
        {count, total} = Map.get(state.bumps, station, {0, 0})
        {station, %{open: open, bumped: count, total_seconds: total}}
      end)

    {:reply, stats, state}
  end

  def handle_call(:next_cook_name, _from, state) do
    number = state.cook_number + 1
    {:reply, "Cook #{number}", %{state | cook_number: number}}
  end

  def handle_call({:claim, station, ticket_id, cook_name}, {pid, _tag}, state) do
    case Map.fetch(state.tickets, ticket_id) do
      {:ok, %Ticket{station: ^station, claimed_by: nil} = ticket} ->
        ticket = %{ticket | claimed_by: cook_name}

        state =
          state
          |> put_in([:tickets, ticket_id], ticket)
          |> put_in([:holders, ticket_id], pid)
          |> monitor(pid)

        Phoenix.PubSub.broadcast(
          Cantina.PubSub,
          "station:#{station}",
          {:claimed, ticket_id, cook_name}
        )

        {:reply, {:ok, ticket}, state}

      {:ok, %Ticket{station: ^station}} ->
        {:reply, {:error, :taken}, state}

      _ ->
        {:reply, {:error, :not_found}, state}
    end
  end

  def handle_call({:bump, station, ticket_id, cook_name}, {pid, _tag}, state) do
    case Map.fetch(state.tickets, ticket_id) do
      {:ok, %Ticket{station: ^station, claimed_by: ^cook_name} = ticket} ->
        if state.holders[ticket_id] == pid do
          {cook_seconds, state} = close(state, ticket)

          Phoenix.PubSub.broadcast_from!(
            Cantina.PubSub,
            pid,
            "station:" <> Atom.to_string(station),
            %{event: "bumped", station: station, ticket_id: ticket_id, secs: cook_seconds}
          )

          Phoenix.PubSub.broadcast(Cantina.PubSub, "expo", {:ticket_ready, ticket})
          Cantina.Orders.ticket_ready(ticket)
          {:reply, {:ok, ticket}, state}
        else
          {:reply, {:error, :not_yours}, state}
        end

      {:ok, %Ticket{station: ^station}} ->
        {:reply, {:error, :not_yours}, state}

      _ ->
        {:reply, {:error, :not_found}, state}
    end
  end

  def handle_call({:auto_bump, ticket_id}, _from, state) do
    {reply, state} = do_auto_bump(state, ticket_id)
    {:reply, reply, state}
  end

  @impl true
  def handle_info({:auto_bump, ticket_id}, state) do
    {_reply, state} = do_auto_bump(state, ticket_id)
    {:noreply, state}
  end

  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    {released, holders} = Enum.split_with(state.holders, fn {_id, holder} -> holder == pid end)

    tickets =
      Enum.reduce(released, state.tickets, fn {ticket_id, _pid}, tickets ->
        %Ticket{station: station} = ticket = Map.fetch!(tickets, ticket_id)
        Phoenix.PubSub.broadcast!(Cantina.PubSub, "station:#{station}", {:released, ticket_id})
        Map.put(tickets, ticket_id, %{ticket | claimed_by: nil})
      end)

    {:noreply,
     %{
       state
       | tickets: tickets,
         holders: Map.new(holders),
         monitors: Map.delete(state.monitors, pid)
     }}
  end

  defp do_auto_bump(state, ticket_id) do
    case Map.fetch(state.tickets, ticket_id) do
      {:ok, %Ticket{station: station} = ticket} ->
        {cook_seconds, state} = close(state, ticket)

        Phoenix.PubSub.broadcast(Cantina.PubSub, "station:#{ticket.station}", %{
          event: "bumped",
          station: station,
          ticket_id: ticket_id,
          secs: cook_seconds
        })

        Phoenix.PubSub.broadcast!(Cantina.PubSub, "expo", {:ticket_ready, ticket})
        Cantina.Orders.ticket_ready(ticket)
        {{:ok, ticket}, state}

      :error ->
        {{:error, :not_found}, state}
    end
  end

  # Removes the ticket, records its cook time, and demonitors a cook with no claim left.
  defp close(state, ticket) do
    cook_seconds = DateTime.diff(DateTime.utc_now(), ticket.fired_at)
    {holder, holders} = Map.pop(state.holders, ticket.id)

    state = %{
      state
      | tickets: Map.delete(state.tickets, ticket.id),
        holders: holders,
        bumps:
          Map.update(state.bumps, ticket.station, {1, cook_seconds}, fn {count, total} ->
            {count + 1, total + cook_seconds}
          end)
    }

    {cook_seconds, maybe_demonitor(state, holder)}
  end

  defp monitor(state, pid) do
    if Map.has_key?(state.monitors, pid) do
      state
    else
      put_in(state.monitors[pid], Process.monitor(pid))
    end
  end

  defp maybe_demonitor(state, nil), do: state

  defp maybe_demonitor(state, pid) do
    if pid in Map.values(state.holders) do
      state
    else
      {ref, monitors} = Map.pop(state.monitors, pid)
      if ref, do: Process.demonitor(ref, [:flush])
      %{state | monitors: monitors}
    end
  end

  defp auto_bump_ms, do: Application.get_env(:cantina, :auto_bump_ms, 45_000)
end
