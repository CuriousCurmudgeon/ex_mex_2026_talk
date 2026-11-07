defmodule Cantina.Presence do
  @moduledoc """
  Tracks diners and cooks.

  Presence broadcasts `presence_diff` on the topics of `Cantina.PubSub.diners_topic/0` and
  `Cantina.PubSub.cooks_topic/0`.
  """

  use Phoenix.Presence, otp_app: :cantina, pubsub_server: Cantina.PubSub

  def track_diner(pid, table_id),
    do: track(pid, Cantina.PubSub.diners_topic(), table_id, %{table_id: table_id})

  @doc "The count of diner screens. Two phones at one table count as two diners."
  def diner_count do
    for {_table_id, %{metas: metas}} <- list(Cantina.PubSub.diners_topic()),
        reduce: 0,
        do: (acc -> acc + length(metas))
  end

  def track_cook(pid, station, name),
    do:
      track(pid, Cantina.PubSub.cooks_topic(), name <> "@" <> Atom.to_string(station), %{
        station: station,
        name: name
      })

  @doc "The count of cooks at each station."
  def cook_counts do
    counts = Map.new(Cantina.Menu.stations(), &{&1, 0})

    for {_key, %{metas: metas}} <- list(Cantina.PubSub.cooks_topic()),
        %{station: station} <- Enum.take(metas, 1),
        reduce: counts do
      acc -> Map.update(acc, station, 1, &(&1 + 1))
    end
  end

  def max_cooks, do: Application.get_env(:cantina, :max_cooks_per_station, 3)
end
