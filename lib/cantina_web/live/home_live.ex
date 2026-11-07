defmodule CantinaWeb.HomeLive do
  @moduledoc """
  The page behind the QR code. A guest picks a job: take a table, cook at a station, or
  run expo.
  """

  use CantinaWeb, :live_view

  alias Cantina.{Kitchen, Menu, Presence}
  alias CantinaWeb.Format

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Cantina.PubSub, "presence:cooks")
    end

    {:ok,
     socket
     |> assign(:page_title, "Pick a job")
     |> assign(:form, to_form(%{"name" => ""}))
     |> assign(:counts, Presence.cook_counts())}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <section class="space-y-1 pt-2">
        <h1 class="text-3xl font-black tracking-tight sm:text-4xl">What's your job tonight?</h1>
        <p class="text-base-content/60">Eat, cook, or run the pass. Pick one.</p>
      </section>

      <button
        id="role-table"
        phx-click="table"
        class="group flex w-full items-center justify-between gap-4 rounded-2xl border-2 border-exmex-turquoise/60 bg-base-200/50 p-6 text-left transition hover:-translate-y-0.5 hover:border-exmex-turquoise hover:shadow-lg active:scale-[0.99]"
      >
        <div>
          <p class="text-2xl font-black">🌮 Grab a table</p>
          <p class="mt-1 text-sm text-base-content/60">Order food from your phone.</p>
        </div>
        <.icon
          name="hero-arrow-right"
          class="size-6 shrink-0 text-base-content/40 transition group-hover:translate-x-1 group-hover:text-exmex-turquoise"
        />
      </button>

      <section id="kitchen" class="space-y-3 rounded-2xl border border-base-300 p-4 sm:p-5">
        <div>
          <h2 class="text-xl font-black">Work the kitchen</h2>
          <p class="text-sm text-base-content/60">Claim tickets at a station and bump them.</p>
        </div>

        <.form for={@form} id="cook-form" phx-change="name" phx-submit="noop">
          <.input
            field={@form[:name]}
            label="Your name"
            placeholder="Leave blank and we'll pick one"
          />
        </.form>

        <div class="grid gap-3 sm:grid-cols-3">
          <%= for station <- Menu.stations() do %>
            <% full? = @counts[station] >= Presence.max_cooks() %>
            <button
              id={"station-#{station}"}
              phx-click="pick"
              phx-value-station={station}
              disabled={full?}
              class="rounded-2xl border border-base-300 bg-base-200/50 p-5 text-left transition hover:-translate-y-0.5 hover:border-amber-500 disabled:translate-y-0 disabled:opacity-50 disabled:hover:border-base-300"
            >
              <p class="text-2xl font-black">{Format.station_label(station)}</p>
              <p class="mt-2 text-sm text-base-content/60">
                {@counts[station]} / {Presence.max_cooks()} cooks
              </p>
              <p :if={full?} class="mt-1 text-sm font-bold text-rose-500">Kitchen full</p>
            </button>
          <% end %>
        </div>
      </section>

      <.link
        id="role-expo"
        navigate={~p"/expo"}
        class="group flex w-full items-center justify-between gap-4 rounded-2xl border border-base-300 bg-base-200/50 p-6 text-left transition hover:-translate-y-0.5 hover:border-emerald-500"
      >
        <div>
          <p class="text-2xl font-black">🛎️ Run expo</p>
          <p class="mt-1 text-sm text-base-content/60">
            Collect each order at the pass and run it out.
          </p>
        </div>
        <.icon
          name="hero-arrow-right"
          class="size-6 shrink-0 text-base-content/40 transition group-hover:translate-x-1 group-hover:text-emerald-500"
        />
      </.link>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("table", _params, socket) do
    {:noreply, push_navigate(socket, to: ~p"/t/#{Enum.random(1..99)}")}
  end

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
