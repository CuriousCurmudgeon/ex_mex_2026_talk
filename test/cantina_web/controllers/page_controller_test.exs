defmodule CantinaWeb.PageControllerTest do
  use CantinaWeb.ConnCase

  test "GET / seats the diner at a random table", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert redirected_to(conn) =~ ~r"^/t/\d+$"
  end
end
