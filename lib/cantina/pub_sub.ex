defmodule Cantina.PubSub do
  @moduledoc """
  Each pub/sub topic of Cantina, and each message on it.

  The `Phoenix.PubSub` server of the app has this module's name. Every broadcast and
  subscribe in the app goes through a function here, so this module is the one place to
  read to learn what is published, where, and in what shape.

  Each message is a two-element tuple, `{event, payload}`, where `payload` is a map. Each
  event name is unique across topics, so a subscriber of many topics matches on the event
  alone.

  | Topic | Subscribe | Messages |
  |---|---|---|
  | `"table:<table_id>"` | `subscribe_table/1` | `:placed`, `:ready`, `:served` |
  | `"station:<station>"` | `subscribe_station/1` | `:fired`, `:claimed`, `:released`, `:bumped` |
  | `"expo"` | `subscribe_expo/0` | `:ticket_ready`, `:order_complete` |
  | `"menu"` | `subscribe_menu/0` | `:special_added` |
  | `"presence:diners"` | `subscribe_diners/0` | `Phoenix.Presence` diffs |
  | `"presence:cooks"` | `subscribe_cooks/0` | `Phoenix.Presence` diffs |
  """

  alias Cantina.{LineItem, MenuItem, Ticket}

  @server __MODULE__

  ## Table: the status of the orders of one table.

  @type table_message ::
          {:placed, %{order_id: String.t(), line_items: [LineItem.t()]}}
          | {:ready, %{order_id: String.t()}}
          | {:served, %{order_id: String.t()}}

  def subscribe_table(table_id), do: subscribe(table_topic(table_id))

  @doc "A diner placed an order."
  def broadcast_placed(table_id, order_id, line_items),
    do:
      broadcast(
        table_topic(table_id),
        {:placed, %{order_id: order_id, line_items: line_items}}
      )

  @doc "The kitchen finished each ticket of the order."
  def broadcast_ready(table_id, order_id),
    do: broadcast(table_topic(table_id), {:ready, %{order_id: order_id}})

  @doc "The expediter ran the order to the table."
  def broadcast_served(table_id, order_id),
    do: broadcast(table_topic(table_id), {:served, %{order_id: order_id}})

  defp table_topic(table_id), do: "table:#{table_id}"

  ## Station: the tickets of one kitchen station.

  @type station_message ::
          {:fired, %{ticket: Ticket.t()}}
          | {:claimed, %{ticket_id: String.t(), cook_name: String.t()}}
          | {:released, %{ticket_id: String.t()}}
          | {:bumped, %{station: atom(), ticket_id: String.t(), cook_seconds: non_neg_integer()}}

  def subscribe_station(station), do: subscribe(station_topic(station))

  @doc "A new ticket reached its station."
  def broadcast_fired(%Ticket{} = ticket),
    do: broadcast(station_topic(ticket.station), {:fired, %{ticket: ticket}})

  @doc "A cook took a ticket."
  def broadcast_claimed(station, ticket_id, cook_name),
    do:
      broadcast(
        station_topic(station),
        {:claimed, %{ticket_id: ticket_id, cook_name: cook_name}}
      )

  @doc "The cook of the ticket left the station."
  def broadcast_released(station, ticket_id),
    do:
      broadcast(
        station_topic(station),
        {:released, %{ticket_id: ticket_id}}
      )

  @doc """
  A ticket is done. The payload carries the station, unlike the other station messages,
  because the board subscribes to each station and needs to know which one. With a `from` pid, the process of the cook that bumped it does not
  receive the message: that screen drops the card itself.
  """
  def broadcast_bumped(from \\ nil, station, ticket_id, cook_seconds) do
    message =
      {:bumped, %{station: station, ticket_id: ticket_id, cook_seconds: cook_seconds}}

    if from,
      do: broadcast_from(from, station_topic(station), message),
      else: broadcast(station_topic(station), message)
  end

  defp station_topic(station) when is_atom(station), do: "station:#{station}"

  ## Expo: tickets that are ready to plate and run.

  @type expo_message ::
          {:ticket_ready, %{ticket: Ticket.t()}}
          | {:order_complete, %{order_id: String.t(), table_id: String.t()}}

  def subscribe_expo, do: subscribe(expo_topic())

  @doc "A station finished its ticket of an order."
  def broadcast_ticket_ready(%Ticket{} = ticket),
    do: broadcast(expo_topic(), {:ticket_ready, %{ticket: ticket}})

  @doc "Each ticket of the order is ready. The order can go out."
  def broadcast_order_complete(order_id, table_id),
    do: broadcast(expo_topic(), {:order_complete, %{order_id: order_id, table_id: table_id}})

  defp expo_topic, do: "expo"

  ## Menu: changes to the menu during service.

  @type menu_message :: {:special_added, %{item: MenuItem.t(), note: String.t() | nil}}

  def subscribe_menu, do: subscribe(menu_topic())

  @doc "The manager added a special."
  def broadcast_special_added(%MenuItem{} = item, note),
    do: broadcast(menu_topic(), {:special_added, %{item: item, note: note}})

  defp menu_topic, do: "menu"

  ## Presence: `Cantina.Presence` tracks on these topics and broadcasts its own diffs.

  def diners_topic, do: "presence:diners"
  def cooks_topic, do: "presence:cooks"

  def subscribe_diners, do: subscribe(diners_topic())
  def subscribe_cooks, do: subscribe(cooks_topic())

  ## Plumbing

  defp subscribe(topic), do: Phoenix.PubSub.subscribe(@server, topic)
  defp broadcast(topic, message), do: Phoenix.PubSub.broadcast(@server, topic, message)

  defp broadcast_from(from, topic, message),
    do: Phoenix.PubSub.broadcast_from(@server, from, topic, message)
end
