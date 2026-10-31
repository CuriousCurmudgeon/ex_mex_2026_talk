defmodule CantinaWeb.StationPickerLive do
  @moduledoc "A volunteer cook picks a station and a name."

  use CantinaWeb, :live_view

  alias Cantina.{Kitchen, Menu, Presence}
  alias CantinaWeb.Format

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      # A plain Phoenix.PubSub topic, next to the manifest.
      :ok = Phoenix.PubSub.subscribe(Cantina.PubSub, Presence.cooks_topic())
    end

    {:ok,
     socket
     |> assign(:page_title, "Kitchen")
     |> assign(:counts, Presence.cook_counts())
     |> assign(:form, to_form(%{"name" => ""}))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} title="Join the line">
      <.form for={@form} id="cook-form" phx-change="name" phx-submit="noop">
        <.input field={@form[:name]} label="Your name" placeholder="Leave blank and we'll pick one" />
      </.form>

      <div class="grid gap-3 sm:grid-cols-3">
        <%= for station <- Menu.stations() do %>
          <% full? = @counts[station] >= Presence.max_cooks() %>
          <button
            id={"station-#{station}"}
            phx-click="pick"
            phx-value-station={station}
            disabled={full?}
            class="group rounded-2xl border border-base-300 bg-base-200/50 p-5 text-left transition hover:-translate-y-0.5 hover:border-amber-500 disabled:translate-y-0 disabled:opacity-50 disabled:hover:border-base-300"
          >
            <p class="text-2xl font-black">{Format.station_label(station)}</p>
            <p class="mt-2 text-sm text-base-content/60">
              {@counts[station]} / {Presence.max_cooks()} cooks
            </p>
            <p :if={full?} class="mt-1 text-sm font-bold text-rose-500">Kitchen full</p>
          </button>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("name", %{"name" => name}, socket) do
    {:noreply, assign(socket, :form, to_form(%{"name" => name}))}
  end

  def handle_event("noop", _params, socket), do: {:noreply, socket}

  def handle_event("pick", %{"station" => station}, socket) do
    name =
      case String.trim(socket.assigns.form[:name].value || "") do
        "" -> Kitchen.next_cook_name()
        name -> String.slice(name, 0, 24)
      end

    {:noreply, push_navigate(socket, to: ~p"/kitchen/#{station}?#{[name: name]}")}
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "presence_diff"}, socket) do
    {:noreply, assign(socket, :counts, Presence.cook_counts())}
  end
end
