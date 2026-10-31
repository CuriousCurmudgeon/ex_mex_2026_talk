defmodule CantinaWeb.ScreensTest do
  # The screens share the named Orders and Kitchen processes, so they run one at a time.
  use CantinaWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Cantina.{Kitchen, Menu, Orders}

  defp table_id, do: "lv-#{System.unique_integer([:positive])}"

  defp ticket_for(station, order_id),
    do: Enum.find(Kitchen.list_tickets(station), &(&1.order_id == order_id))

  describe "diner" do
    test "orders food and follows the order to served", %{conn: conn} do
      table_id = table_id()
      {:ok, view, html} = live(conn, ~p"/t/#{table_id}")
      assert html =~ "Table #{table_id}"

      view |> element("button[aria-label='More Margarita']") |> render_click()
      view |> element("button[aria-label='More Margarita']") |> render_click()
      assert view |> element("#place-order") |> render() =~ "Order 2 items"

      view |> element("#place-order") |> render_click()
      [order] = Orders.list_orders(table_id)
      assert render(view) =~ "In the kitchen"

      bar = ticket_for(:bar, order.id)
      {:ok, _} = Kitchen.auto_bump(bar.id)
      assert render_async_until(view, "Ready")

      {:ok, _} = Orders.serve(order.id)
      assert render_async_until(view, "Served")
    end

    test "sees a new special", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/t/#{table_id()}")
      {:ok, _} = Menu.add_special(%{name: "Elote", station: :grill, price_cents: 600}, nil)
      assert render(view) =~ "Elote"
    end
  end

  describe "station" do
    test "claims and bumps a ticket, and another cook sees the lock", %{conn: conn} do
      {:ok, ana, _} = live(conn, ~p"/kitchen/fryer?name=Ana")
      {:ok, ben, _} = live(conn, ~p"/kitchen/fryer?name=Ben")

      {:ok, order} = Orders.place(table_id(), %{"churros" => 1})
      ticket = ticket_for(:fryer, order.id)
      card = "#ticket-#{ticket.id}"

      assert ana |> element(card) |> render() =~ "Churros"
      ana |> element("#{card} button", "Claim") |> render_click()
      assert ana |> element(card) |> render() =~ "Bump"
      assert ben |> element(card) |> render() =~ "Taken by Ana"

      ana |> element("#{card} button", "Bump") |> render_click()
      refute has_element?(ana, card)
      refute has_element?(ben, card)
    end

    test "releases the claim when the cook leaves", %{conn: conn} do
      {:ok, ana, _} = live(conn, ~p"/kitchen/grill?name=Ana")
      {:ok, ben, _} = live(conn, ~p"/kitchen/grill?name=Ben")

      {:ok, order} = Orders.place(table_id(), %{"flautas" => 0, "cheese-quesadilla" => 1})
      card = "#ticket-#{ticket_for(:grill, order.id).id}"

      ana |> element("#{card} button", "Claim") |> render_click()
      assert ben |> element(card) |> render() =~ "Taken by Ana"

      ref = Process.monitor(ana.pid)
      GenServer.stop(ana.pid)
      assert_receive {:DOWN, ^ref, _, _, _}

      assert render_async_until(ben, "Claim")
    end

    test "an unknown station goes back to the picker", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/kitchen"}}} =
               live(conn, ~p"/kitchen/oven?name=Ana")
    end
  end

  describe "station picker" do
    test "sends the cook to a station with a name", %{conn: conn} do
      {:ok, view, _} = live(conn, ~p"/kitchen")
      view |> form("#cook-form", %{"name" => "Rosa"}) |> render_change()
      view |> element("#station-bar") |> render_click()
      assert_redirect(view, ~p"/kitchen/bar?name=Rosa")
    end

    test "gives a name to a cook that leaves it blank", %{conn: conn} do
      {:ok, view, _} = live(conn, ~p"/kitchen")
      view |> element("#station-grill") |> render_click()
      {path, _flash} = assert_redirect(view)
      assert path =~ ~r"^/kitchen/grill\?name=Cook\+\d+$"
    end
  end

  describe "expo" do
    test "runs a complete order", %{conn: conn} do
      {:ok, view, _} = live(conn, ~p"/expo")
      {:ok, order} = Orders.place(table_id(), %{"agua-fresca" => 1})
      {:ok, _} = Kitchen.auto_bump(ticket_for(:bar, order.id).id)

      card = "#order-#{order.id}"
      assert render_async_until(view, "Run it")
      view |> element("#{card} button", "Run it") |> render_click()

      refute has_element?(view, card)
      assert %{status: :served} = Orders.get_order(order.id)
    end
  end

  describe "board" do
    test "counts tickets and shows the feed", %{conn: conn} do
      {:ok, view, _} = live(conn, ~p"/board")
      before = Kitchen.stats().grill.open

      {:ok, order} = Orders.place(table_id(), %{"al-pastor-tacos" => 3})
      assert view |> element("#stats-grill") |> render() =~ Integer.to_string(before + 1)
      assert view |> element("#feed-#{order.id}") |> render() =~ "3× Al pastor tacos"
    end

    test "adds a special", %{conn: conn} do
      {:ok, view, _} = live(conn, ~p"/board")

      view
      |> form("#special-form", %{
        name: "Tres leches",
        station: "fryer",
        price: "7",
        note: "House made"
      })
      |> render_submit()

      assert view |> element("#specials") |> render() =~ "Tres leches"
      assert Enum.any?(Menu.list_items(), &(&1.name == "Tres leches" and &1.price_cents == 700))
    end

    test "starts and stops the rush", %{conn: conn} do
      {:ok, view, _} = live(conn, ~p"/board")
      assert view |> element("#rush-toggle") |> render_click() =~ "Stop the rush"
      assert view |> element("#rush-toggle") |> render_click() =~ "Start the rush"
    end
  end

  # Broadcasts reach the LiveView in another process. Retries a render until it shows the text.
  defp render_async_until(view, text, tries \\ 20) do
    cond do
      render(view) =~ text ->
        true

      tries == 0 ->
        flunk("#{text} never rendered")

      true ->
        Process.sleep(10)
        render_async_until(view, text, tries - 1)
    end
  end
end
