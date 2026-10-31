defmodule CantinaWeb.PageController do
  use CantinaWeb, :controller

  @doc "Seats a diner at a random table."
  def home(conn, _params) do
    redirect(conn, to: ~p"/t/#{Enum.random(1..99)}")
  end
end
