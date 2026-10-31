defmodule Cantina.Presence do
  @moduledoc """
  Tracks diners and cooks.

  Presence uses plain `Phoenix.PubSub` topics, next to the manifest of `Cantina.Topics`.
  """

  use Phoenix.Presence, otp_app: :cantina, pubsub_server: Cantina.PubSub

  @diners "presence:diners"
  @cooks "presence:cooks"

  def diners_topic, do: @diners
  def cooks_topic, do: @cooks

  def track_diner(pid, table_id), do: track(pid, @diners, table_id, %{table_id: table_id})

  @doc "The count of diner screens. Two phones at one table count as two diners."
  def diner_count do
    for {_table_id, %{metas: metas}} <- list(@diners), reduce: 0, do: (acc -> acc + length(metas))
  end

  def track_cook(pid, station, name),
    do:
      track(pid, @cooks, name <> "@" <> Atom.to_string(station), %{station: station, name: name})

  @doc "The count of cooks at each station."
  def cook_counts do
    counts = Map.new(Cantina.Menu.stations(), &{&1, 0})

    for {_key, %{metas: metas}} <- list(@cooks),
        %{station: station} <- Enum.take(metas, 1),
        reduce: counts do
      acc -> Map.update(acc, station, 1, &(&1 + 1))
    end
  end

  def max_cooks, do: Application.get_env(:cantina, :max_cooks_per_station, 3)
end
