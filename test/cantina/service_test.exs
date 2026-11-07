defmodule Cantina.ServiceTest do
  # Orders, Kitchen, and Menu are named processes, so these tests run one at a time.
  use ExUnit.Case, async: false

  alias Cantina.{Kitchen, Menu, Orders, Ticket}

  defp table_id, do: "test-#{System.unique_integer([:positive])}"

  # Places an order with one grill item and one bar item. Returns the order and its tickets.
  defp place_order(table_id) do
    for station <- [:grill, :bar], do: :ok = Cantina.PubSub.subscribe_station(station)
    :ok = Cantina.PubSub.subscribe_table(table_id)

    {:ok, order} = Orders.place(table_id, %{"carne-asada-tacos" => 2, "horchata" => "1"})

    assert_receive {:ticket_fired, %{ticket: %{station: :grill} = grill}}
    assert_receive {:ticket_fired, %{ticket: %{station: :bar} = bar}}
    assert_receive {:order_placed, %{order_id: order_id}}
    assert order_id == order.id

    {order, grill, bar}
  end

  defp claim_from_other_process(station, ticket_id, name) do
    parent = self()

    pid =
      spawn(fn ->
        send(parent, {:claimed, Kitchen.claim(station, ticket_id, name)})
        Process.sleep(:infinity)
      end)

    assert_receive {:claimed, {:ok, %Ticket{claimed_by: ^name}}}
    pid
  end

  test "place/2 splits an order into one ticket for each station" do
    {order, grill, bar} = place_order(table_id())

    assert order.stations == %{grill: :cooking, bar: :cooking}
    assert [%{name: "Carne asada tacos", quantity: 2}] = grill.line_items
    assert [%{name: "Horchata", quantity: 1}] = bar.line_items
    assert Enum.any?(Kitchen.list_tickets(:grill), &(&1.id == grill.id))
  end

  test "place/2 rejects an empty order" do
    assert {:error, :empty} = Orders.place(table_id(), %{"carne-asada-tacos" => 0, "nope" => 3})
  end

  test "the claim lock allows one cook for each ticket" do
    {_order, grill, _bar} = place_order(table_id())

    assert {:ok, %Ticket{claimed_by: "Ana"}} = Kitchen.claim(:grill, grill.id, "Ana")
    assert_receive {:ticket_claimed, %{ticket_id: id, cook_name: "Ana"}}
    assert id == grill.id

    assert {:error, :taken} = Kitchen.claim(:grill, grill.id, "Ben")
    assert {:error, :not_yours} = Kitchen.bump(:grill, grill.id, "Ben")
  end

  test "a cook with the same name in another process cannot bump the ticket" do
    {_order, grill, _bar} = place_order(table_id())
    claim_from_other_process(:grill, grill.id, "Ana")

    assert {:error, :not_yours} = Kitchen.bump(:grill, grill.id, "Ana")
  end

  test "the kitchen releases the tickets of a cook whose process exits" do
    {_order, grill, _bar} = place_order(table_id())
    pid = claim_from_other_process(:grill, grill.id, "Ana")
    grill_id = grill.id

    Process.exit(pid, :kill)

    assert_receive {:ticket_released, %{ticket_id: ^grill_id}}

    assert %Ticket{claimed_by: nil} =
             Enum.find(Kitchen.list_tickets(:grill), &(&1.id == grill_id))
  end

  test "bump skips the screen of the cook, and the order completes when each ticket is ready" do
    table_id = table_id()
    :ok = Cantina.PubSub.subscribe_expo()
    {order, grill, bar} = place_order(table_id)
    order_id = order.id

    {:ok, _} = Kitchen.claim(:grill, grill.id, "Ana")
    assert {:ok, _} = Kitchen.bump(:grill, grill.id, "Ana")

    # The bump skips the process of the cook.
    grill_id = grill.id
    refute_receive {:ticket_bumped, %{ticket_id: ^grill_id}}, 50
    assert_receive {:ticket_ready, %{ticket: %{id: ^grill_id}}}
    assert {:error, :not_ready} = Orders.serve(order_id)

    # The kitchen bumps the bar ticket itself, so each screen drops the card.
    bar_id = bar.id
    assert {:ok, _} = Kitchen.auto_bump(bar_id)
    assert_receive {:ticket_bumped, %{ticket_id: ^bar_id, cook_seconds: s}}
    assert is_integer(s)

    assert_receive {:order_complete, %{order_id: ^order_id, table_id: ^table_id}}
    assert_receive {:order_ready, %{order_id: ^order_id}}

    assert {:ok, %{status: :served}} = Orders.serve(order_id)
    assert_receive {:order_served, %{order_id: ^order_id}}
    refute Enum.any?(Orders.list_open_orders(), &(&1.id == order_id))
  end

  test "add_special/2 adds an item and broadcasts it" do
    :ok = Cantina.PubSub.subscribe_menu()

    assert {:ok, item} =
             Menu.add_special(
               %{name: "Birria tacos", station: :grill, price_cents: 1400},
               "Tonight only"
             )

    assert_receive {:special_added, %{item: ^item, note: "Tonight only"}}
    assert item in Menu.list_items()

    assert {:error, :invalid} =
             Menu.add_special(%{name: "", station: :grill, price_cents: 1}, nil)
  end
end
