defmodule Cantina.Rush do
  @moduledoc """
  Fills the kitchen without phones. While it runs, it places a random order every few
  seconds, and it bumps an unclaimed ticket that waits too long. The board starts and
  stops it.
  """

  use GenServer

  alias Cantina.{Kitchen, Menu, Orders}

  @stale_seconds 20

  def start_link(_opts), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)

  def start, do: GenServer.call(__MODULE__, :start)
  def stop, do: GenServer.call(__MODULE__, :stop)
  def running?, do: GenServer.call(__MODULE__, :running?)

  @impl true
  def init(:ok), do: {:ok, %{running?: false, timer: nil}}

  @impl true
  def handle_call(:start, _from, %{running?: true} = state), do: {:reply, :ok, state}
  def handle_call(:start, _from, state), do: {:reply, :ok, schedule(%{state | running?: true})}

  def handle_call(:stop, _from, state) do
    if state.timer, do: Process.cancel_timer(state.timer)
    {:reply, :ok, %{state | running?: false, timer: nil}}
  end

  def handle_call(:running?, _from, state), do: {:reply, state.running?, state}

  @impl true
  def handle_info(:tick, %{running?: true} = state) do
    place_random_order()
    bump_stale_tickets()
    {:noreply, schedule(state)}
  end

  def handle_info(:tick, state), do: {:noreply, state}

  defp schedule(state) do
    interval = Application.get_env(:cantina, :rush_interval_ms, 2_500)
    %{state | timer: Process.send_after(self(), :tick, interval + :rand.uniform(interval))}
  end

  defp place_random_order do
    quantities =
      Menu.list_items()
      |> Enum.filter(& &1.available?)
      |> Enum.take_random(Enum.random(1..3))
      |> Map.new(&{&1.id, Enum.random(1..2)})

    Orders.place(Integer.to_string(Enum.random(1..99)), quantities)
  end

  defp bump_stale_tickets do
    now = DateTime.utc_now()

    for station <- Menu.stations(),
        %{claimed_by: nil} = ticket <- Kitchen.list_tickets(station),
        DateTime.diff(now, ticket.fired_at) >= @stale_seconds do
      Kitchen.auto_bump(ticket.id)
    end
  end
end
