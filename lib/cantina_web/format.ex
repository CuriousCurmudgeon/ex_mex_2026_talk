defmodule CantinaWeb.Format do
  @moduledoc "Formats kitchen values for the screens."

  def price(cents), do: "$" <> :erlang.float_to_binary(cents / 100, decimals: 2)

  def station_label(:grill), do: "🔥 Grill"
  def station_label(:fryer), do: "🍟 Fryer"
  def station_label(:bar), do: "🍹 Bar"

  def station_name(station), do: station |> Atom.to_string() |> String.capitalize()

  @doc "The seconds since `datetime`."
  def age(datetime, now), do: max(DateTime.diff(now, datetime), 0)

  def clock(seconds),
    do:
      "#{div(seconds, 60)}:#{seconds |> rem(60) |> Integer.to_string() |> String.pad_leading(2, "0")}"
end
