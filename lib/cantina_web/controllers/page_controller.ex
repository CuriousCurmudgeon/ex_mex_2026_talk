defmodule CantinaWeb.PageController do
  use CantinaWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
