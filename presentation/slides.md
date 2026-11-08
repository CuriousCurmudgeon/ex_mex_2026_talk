---
marp: true
theme: bare
paginate: false
---

<!-- _class: title statement -->

# Preventing Pub/Sub Spaghetti in Event-Driven Systems

Brian Meeker

<!--
Good day everybody. How's your ExMex been?

Usually, I start my talks by reminding everybody about the rule of two feet. If the content of this talk just isn't working for you, vote with your feet and go make better use of your time. I won't be offended. This is a single track conference though, so your choices are this talk or the hallway track. I still won't be offended if you leave though. The hallway track is pretty great.
-->

---

<div class="columns">
<div>

# Brian Meeker

Engineering Manager, GetThru

<span class="accent">@brianmeeker.bsky.social</span>

</div>
<div class="center">

<img class="qr" src="images/qr-repo.svg" alt="QR code to the talk repo">

<span class="caption">github.com/CuriousCurmudgeon/ex_mex_2026_talk</span>

</div>
</div>

<!--
My name is Brian Meeker. I've traveled here today from the far off lands of Indiana.

I spend my work hours as the engineering manager at GetThru. Because of the upheaval in our industry over the past year, I still get to write code. Well, a robot writes code for me, but I still get to tell myself that I'm writing code.

You can mostly find me these days on Bluesky. These slides will be available on GitHub. That same QR code will be up at end as well.
-->

---

<div class="columns">
<div class="center">

<img class="qr" src="images/qr-texmex.svg" alt="QR code to texmex.fly.dev">

## texmex.fly.dev

</div>
<div class="center">

<img class="phone" src="images/home-phone.png" alt="The home page of the Tex Mex demo app on a phone">

</div>
</div>

<!--
Today we're going to be talk about pub/sub. We'll talk about what we get out of the box with Phoenix Pub/Sub. We'll talk about the kinds of messes you can make with this. And then we'll talk about how we can layer compile-time guarantees on top of pub/sub to help out both human and LLM-assisted development. Because, at least for the current time being, most things you do to make development better for humans also happens to make it better for robots as well.

All code examples today are pulled from the demo app in the git repo. We're at ExMex, so what better way to walk through our examples than with a demo app for a Tex Mex restaraunt. You can find it at https://texmex.fly.dev/

Feel free to play around with this or pull down the code. It's all vibes and it makes good use of pub/sub to broadcast events as orders are put in and they are handled by the back of house. You can place orders or get a job.
-->

---

<!-- _class: statement -->

# What kind of messes can you make with pub/sub?

<!--
What kind of messes can you make with pub/sub though? What pain points were we running into at work?

GetThru's code base recently passed the 10 year mark. I've worked on older code bases than this, but this is one of the older ones. And like most older code bases, a lot of people have worked on it over the years. Historically, we work in the election industry, so as election time approached, there would be pressure to rapidly address issues and add new features for important clients.
-->

---

<!-- _class: statement -->

# We'll clean it up later

<!--
And then the promised time to clean it up later would rarely materialize This combination of many hands and time pressure does not lead to great solutions. Our pub/sub usage had grown haphazardly this entire time. It had never been seriously refactored.

This mean that nothing was centralized. Every module directly used the functions exposed in the default Pub/Sub module you get with a new Phoenix app. In many ways, this is similar to the context module problem. People see what the generator gives you out of the box and just assume that is how it needs to stay. It's not.
-->

---

<!-- _class: statement -->

# Phoenix is not that magical

<!--
Are there any old Rails devs in the room? Or maybe veterans of other frameworks that are very opinionated and magical? Have you ever worked on teams where most of them are afraid to change the structure of anything that came out of the box? Rails apps that have no concept of code living somewhere other than a model, view, or controller? I have.

It doesn't have to be that way though! Phoenix is not that magical. That pub/sub module that got generated? It's not magic. You can add functions to it. You can move it wherever you want!

For example, I think that it's silly to have the generated pub/sub module be in the web project for a new app. Now my business layer needs to take a dependency on something in the web layer. That's wrong. Move that generated pub/sub module wherever you want. Module names and directories have no meaning in Elixir. Move them where ever you want!
-->

---

<!-- _class: statement -->

# Code generators are merely a suggestion

<!--
Code generators are merely a suggestion for how to get started. You don't have to stick with just that. Constraints are great when getting started. I'm a firm believer in the aphorism that constraints breed creativity. Generators help with the blank page problem. But after that they are merely a suggestion.
-->

---

<!-- _class: statement -->

# What pain points were we seeing?

<!--
Circling back around though, what was GetThru's problem? What pain points were we seeing?

Because every module was responsible for subscribing and broadcasting directly, there was no reasonable way to find what our pub/sub API was. There was no way to easily see what the name of a topic is. No way to keep topic naming consistent. No way to keep event naming on those topics consistent. No way to keep the shape of the payloads for those events consistent.

And, at another level, we hadn't defined what our expected behavior was for subscribers. If a process subscribes to a topic, does it have to have an explicit handler for every possible event? What happens if unexpected events are sent? Is it ok to have a catch-all handler? If so, what should the behavior of that handler be? Should it log a warning? Should it raise and crash the process? Nobody knew. Nobody had decided what the behavior should be, so it was a combination of all of those. There was no consistency.
-->

---

```elixir
# Cantina.Orders

for ticket <- tickets do
  :ok = Kitchen.open(ticket)

  Phoenix.PubSub.broadcast(
    Cantina.PubSub,
    "stations:#{ticket.station}",
    {:fired, ticket}
  )
end
```

<!--
Going down that path with our TexMex app, here you can see how we broadcast tickets to kitchen stations. An order comes in and each line item is sent to appropriate kitchen station.
-->

---

```elixir
# CantinaWeb.StationLive

if connected?(socket) do
  Phoenix.PubSub.subscribe(Cantina.PubSub, "stations:#{station}")
  Phoenix.PubSub.subscribe(Cantina.PubSub, "menu")
  # ...
end
```

<!--
Each kitchen station then subscribe to the topic for their station
-->

---

<!-- _class: small-code -->

```elixir
# CantinaWeb.StationLive

def handle_info({:fired, ticket}, socket), do: {:noreply, put_ticket(socket, ticket)}

def handle_info({:claimed, id, name}, socket) do
  {:noreply, update_ticket(socket, id, &%{&1 | claimed_by: name})}
end

def handle_info({:released, id}, socket),
  do: {:noreply, update_ticket(socket, id, &%{&1 | claimed_by: nil})}

def handle_info(%{event: "bumped", ticket_id: id}, socket) do
  {:noreply, drop_ticket(socket, id)}
end

def handle_info({:special_added, item, _note}, socket) do
  # ...
end
```

<!--
and handles the event with handle_info.

This about the most basic way to do pub/sub in an Elixir app. Just call the raw functions. And this can be fine! If your app is small, then you don't need any more complexity. But when your app is larger, then this becomes unwieldy. It becomes difficult to keep track of your API for pub/sub. What topics does your app use? What is your preferred naming pattern for topics? What conventions do you want for the shape of payloads? What about the weight of payloads? Should you pass only ids around or should you pass structs with more info?
-->

---

<!-- _class: statement -->

# All three of them sent a differently shaped payload

<!--
Answering those questions is harder unless you start centralizing your management of pub/sub

The first thing we did to start addressing these issues was to start centralizing pub/sub subscribe and broadcast functions in a single module. This started making it easier to understand what pub/sub the app was even doing.

We started doing this work in 2024. These days it would be pretty easy to use your LLM of choice to have one big PR that made a cross-cutting change across the app to centralize all the subscribe and broadcast functions.

Like us, when you do this you will probably start finding the source of various bugs. The worst one that we found was three different rarely used live views that all broadcast the same event on the same topic, but all three of them sent a differently shaped payload. This was difficult to spot before. It was extremely rare for more than one of these to open at the same time and see this uncommon event be published. Because of that, it was never a priority to dig into our error tracker and figure it out.
-->

---

```elixir
# Cantina.Orders

for ticket <- tickets do
  :ok = Kitchen.open(ticket)
  Cantina.PubSub.broadcast_fired(ticket)
end

Cantina.PubSub.broadcast_placed(table_id, order_id, line_items)
```

<!--
Here's the same example from our Tex Mex sample app with this approach. We can see that we're just calling functions still, but it's functions that we've defined in the Cantina.PubSub module.
-->

---

<!-- _class: small-code -->

```elixir
# CantinaWeb.StationLive

if connected?(socket) do
  :ok = Cantina.PubSub.subscribe_station(station)
  :ok = Cantina.PubSub.subscribe_menu()
  # ...
end
```

---

<!-- _class: small-code -->

```elixir
# CantinaWeb.StationLive

def handle_info({:fired, %{ticket: ticket}}, socket),
  do: {:noreply, put_ticket(socket, ticket)}

def handle_info({:claimed, %{ticket_id: id, cook_name: name}}, socket),
  do: {:noreply, update_ticket(socket, id, &%{&1 | claimed_by: name})}

def handle_info({:released, %{ticket_id: id}}, socket),
  do: {:noreply, update_ticket(socket, id, &%{&1 | claimed_by: nil})}

def handle_info({:bumped, %{ticket_id: id}}, socket),
  do: {:noreply, drop_ticket(socket, id)}
```

---

<!-- _class: small-code -->

```elixir
defmodule Cantina.PubSub do
  @type station_message ::
          {:fired, %{ticket: Ticket.t()}}
          | {:claimed, %{ticket_id: String.t(), cook_name: String.t()}}
          | {:released, %{ticket_id: String.t()}}
          | {:bumped, %{station: atom(), ticket_id: String.t(), cook_seconds: non_neg_integer()}}

  # ...
end
```

---

<!-- _class: small-code -->

```elixir
defmodule Cantina.PubSub do
  def subscribe_station(station), do: subscribe(station_topic(station))

  @doc "A new ticket reached its station."
  def broadcast_fired(%Ticket{} = ticket),
    do: broadcast(station_topic(ticket.station), {:fired, %{ticket: ticket}})

  @doc "A cook took a ticket."
  def broadcast_claimed(station, ticket_id, cook_name),
    do:
      broadcast(
        station_topic(station),
        {:claimed, %{ticket_id: ticket_id, cook_name: cook_name}}
      )

  defp station_topic(station) when is_atom(station), do: "stations:#{station}"

  defp subscribe(topic), do: Phoenix.PubSub.subscribe(@server, topic)
  defp broadcast(topic, message), do: Phoenix.PubSub.broadcast(@server, topic, message)
end
```

<!--
And they don't have to live in the PubSub module. Maybe in your app it makes more sense for them to live in various context modules. That's fine. As long as you know where they are and can easily find your topics, events, and payloads, you're way ahead of most.
-->

---

<!-- _class: statement -->

# It might still be a plate of spaghetti

<!--
But having consistency is only half the battle here. You've made it easier to find the surface area of your pub/sub API. It won't be a big ball of mud anymore. It might still be a plate of spaghetti, but that is way more appetizing than a big ball of mud.

Another thing that can help is a style guide for LLMs. We have guidance for how to document functions that broadcast on topics. We have guidance for how to document a module that subscribes to topics. The robots are really good at this kind of thing. You can have reliable mix docs that describe what functions broadcast and what modules subscribe. This is another example of something helping humans that also happens to help the robots as well.
-->

---

```elixir
# CantinaWeb.HomeLive

def handle_event("pick", %{"station" => station}, socket) do
  name =
    case String.trim(socket.assigns.form[:name].value || "") do
      "" -> Kitchen.next_cook_name()
      name -> String.slice(name, 0, 24)
    end

  {:noreply, push_navigate(socket, to: ~p"/kitchen/#{station}?#{[name: name]}")}
end
```

<!--
This is all well and good, but we can do better. I'm a big fan of verified routes in Phoenix. This uses the router as a DSL to build up data structure of valid routes in our application. They give you compile-time validation that the routes you're using are correct.
-->

---

<!-- _class: statement -->

# What if we did the same thing for pub/sub?

<!--
What if we did the same thing for pub/sub? Could we enforce compile-time validation that you're broadcasting and subscribing to documented topics? Can we guarantee that a module handles all events on a topic? What about the shape of the message payload? What would we need to do that?
-->

---

<!-- _class: statement -->

# verified_pubsub

<!--
So I did that with a new library called verified_pubsub. This is an idea that had been percolating in the back of my mind for the past two years. The problem was that I'm a very mediocre programmer with macros. I had never tried anything this complicated. I knew I could figure it out, but I also wasn't willing to spend a bunch of evenings and weekends working on it. I have hobbies. I have kids. I enjoy programming, but I'm not the kind of guy who's interested in spending many of his nights and weekends working on these things.
-->

---

<div class="columns wide-left">
<div>

<img class="thumbnail" src="images/quinn-thumbnail.jpg" alt="Graveyard of Good Ideas, Quinn Wilton, ElixirConf US 2026">

</div>
<div class="center">

<img class="qr" src="images/qr-quinn.svg" alt="QR code to the talk on YouTube">

</div>
</div>

<!--
But we have LLMs now. Quinn Wilton's talk at ElixirConf US this year has really stuck with me. The barrier between that idea in your head and a working implementation has never been smaller. Quinn was talking about really ambitious projects that previously would have taken hundreds or thousands of hours to implement. They may have needed an entire team all putting in those kinds of hours. That is not the case anymore.

I watched her talk knowing this was true. I had this idea for years that I had not been able to justify spending the time on. But I had vibe coded an initial version of it in 4-5 hours a few Sundays before ElixirConf while doing other work around my house.
-->

---

<!-- _class: statement -->

# Those pain points in your codebase can go away now

<!--
If you take nothing else away from this talk, it should be this. Those pain points in your codebase can go away now. If it's a technical problem and you can articulate what properties you want the system or library to have, the robot can probably quickly build it for you. This is wild. The future is wild.
-->

---

<!-- _class: statement -->

# Let your mind wander

<!--
As I walk through this library, let your mind wander. You may not like my solution to this problem. If you can articulate what you don't like about it, you can quickly generate your own solution. Maybe you don't like my API. Maybe you don't like the dependency on Spark. Whatever it is, you can talk to me. And if my spongey brain matter disagrees with you and doesn't want those changes, it's trivial to fork my version or build your own.

Let's look at the API b
-->

---

```elixir
# CantinaWeb.Router

scope "/", CantinaWeb do
  pipe_through :browser

  live "/", HomeLive

  live "/t/:table_id", DinerLive
  live "/kitchen/:station", StationLive
  live "/expo", ExpoLive
  live "/board", BoardLive
end
```

<!--
Verified routes derives valid routes through the router module.
-->

---

<!-- _class: small-code -->

```elixir
defmodule Cantina.Manifest do
  use VerifiedPubSub.Manifest, pubsub: Cantina.PubSub

  topic :table, ["tables", :table_id] do
    description "The status of the orders of one table."

    message :placed do
      field :order_id, :string
      field :line_items, {:list, Cantina.LineItem}
    end

    message :ready do
      description "The kitchen finished each ticket of the order."
      field :order_id, :string
    end

    message :served do
      field :order_id, :string
    end
  end
end
```

<!--
Phoenix PubSub has no equivalent module to organize topics and messages, so we have to make our own. Enter the manifest module

Manifest here means something like a shipping manifest. A shipping manifest lists everything and everybody on a ship. Here, we want to list all the topics, the messages on those topics, and the shape of the payload for those messages. Not quite a 1:1 mapping on to a shipping manifest, but the name works well enough.
-->

---

```elixir
topic :table, ["tables", :table_id]
```

```
"tables:42"
"tables:7"
```

<!--
Looking at the topic we have here, the first atom is a unique name for your topic. This is not the shape of the topic on the wire. That part is defined by the list. So, the topic on the wire ends up becoming something "tables:42", "tables:7", etc.

This DSL uses Spark. It gives us the equivalent of a router module for pub/sub. This lets us gather metadata for what every topic and message looks like, including the shape of the payload of each message.
-->

---

```elixir
# Cantina.Orders

for ticket <- tickets do
  :ok = Kitchen.open(ticket)
  broadcast!(:station, %{station: ticket.station}, :fired, %{ticket: ticket})
end

broadcast!(:table, %{table_id: table_id}, :placed, %{
  order_id: order_id,
  line_items: line_items
})
```

<!--
How do we use it though? I strived to make the API pretty similar to phoenix_pubsub, deviating only where it made sense.

We call broadcast with or without a bang. The :table atom matches the name of the topic in the manifest. The table_id is interpolated into the topic name, so we get something like "tables:42" again. After that is the name of the message, :placed in this case. Finally, there is the payload of the message itself. The manifest says the message has order_id and line_items fields.
-->

---

```elixir
topic :table, ["tables", :table_id] do
  message :placed do
    field :order_id, :string
    field :line_items, {:list, Cantina.LineItem}
  end
end
```

---

```elixir
# Cantina.Kitchen

broadcast_from!(pid, :station, %{station: station}, :bumped, %{
  ticket_id: ticket_id,
  cook_seconds: cook_seconds
})
```

<!--
Just like phoenix_pubsub, you can also call broadcast_from, with or without the bang.
-->

---

```elixir
defmodule CantinaWeb.DinerLive do
  use CantinaWeb, :live_view
  use VerifiedPubSub.Subscriber, manifest: Cantina.Manifest

  @impl true
  def mount(%{"table_id" => table_id}, _session, socket) do
    if connected?(socket) do
      :ok = subscribe(:table, %{table_id: table_id})
      :ok = subscribe(:menu)
    end

    # ...
  end
end
```

<!--
How do we subscribe to these topics though?

It looks pretty much like you would expect. We subscribe to the :table topic. A map is passed just like when broadcasting to fill in the table_id. You get back an :ok atom on success, just like phoenix_pubsub.
-->

---

```elixir
# CantinaWeb.DinerLive

handle_broadcast :table, :ready, %{order_id: id}, socket do
  {:noreply, set_status(socket, id, :ready)}
end
```

<!--
Handling messages looks different though. Instead of handle_info, we use a handle_broadcast macro.

Here we see an example of handling the :ready event on the :table topic. This message has an order_id, which we pattern match.

Now, I talked earlier about a philosophical disagreement on the team about how we handle unexpected events on a topic. verified_pubsub makes the choice that every message must be explicitly handled or ignored. You can choose to ignore with ignore_broadcast
-->

---

```elixir
# CantinaWeb.BoardLive

ignore_broadcast :station, [:claimed, :released]

ignore_broadcast :expo, :ticket_ready
```

<!--
In this example, we can see this live view subscribes to a couple of topics that have messages we don't actually care about. We must explicitly handle or ignore every message on a topic.
-->

---

<!-- _class: small-code -->

```elixir
broadcast!(:tables, %{table_id: table_id}, :placed, %{
```

```
** (CompileError) lib/cantina/orders.ex:96: unknown topic :tables in Cantina.Manifest.

Declared topics:
  :expo      expo                 lib/cantina/manifest.ex:52
  :menu      menu                 lib/cantina/manifest.ex:65
  :station   stations:<station>   lib/cantina/manifest.ex:29
  :table     tables:<table_id>    lib/cantina/manifest.ex:11
```

<!--
Now we get to the fun parts. The library is called verified_pubsub, but what can we actually verify with this? The manifest lets us do a lot.

We can verify that the topic exists.
-->

---

<!-- _class: small-code -->

```elixir
broadcast!(:table, %{table: table_id}, :placed, %{
```

```
** (CompileError) lib/cantina/orders.ex:96: wrong params for topic :table.

  missing: [:table_id]
  unexpected: [:table]

:table is tables:<table_id>, so it takes exactly [:table_id].
:table is declared at lib/cantina/manifest.ex:11.
```

<!--
We can verify that the topic is given the correct params to be built.
-->

---

<!-- _class: small-code -->

```elixir
broadcast!(:table, %{table_id: table_id}, :paid, %{
```

```
** (CompileError) lib/cantina/orders.ex:96: unknown event :paid on topic :table (tables:<table_id>).

Declared events: [:placed, :ready, :served]
:table is declared at lib/cantina/manifest.ex:11.
```

<!--
We can verify that the message we're broadcasting exists in the manifest
-->

---

<!-- _class: small-code -->

```elixir
broadcast!(:table, %{table_id: table_id}, :placed, %{
  order_id: order_id,
  line_items: line_items,
  tip: 5
})
```

```
** (CompileError) lib/cantina/orders.ex:96: invalid payload for :table :placed.

  unexpected: [:tip]

Declared at lib/cantina/manifest.ex:14:

    field :order_id, :string
    field :line_items, {:list, Cantina.LineItem}
```

<!--
We can verify that the payload of the message has the correct shape.
-->

---

<!-- _class: small-code -->

```elixir
:ok = subscribe(:tables, %{table_id: table_id})
```

```
** (CompileError) lib/cantina_web/live/diner_live.ex:13: unknown topic :tables in Cantina.Manifest.

Declared topics:
  :expo      expo                 lib/cantina/manifest.ex:52
  :menu      menu                 lib/cantina/manifest.ex:65
  :station   stations:<station>   lib/cantina/manifest.ex:29
  :table     tables:<table_id>    lib/cantina/manifest.ex:11
```

<!--
We can verify that you subscribing to a topic that exists in the manifest
-->

---

<!-- _class: small-code -->

```elixir
:ok = subscribe(:table, %{id: table_id})
```

```
** (CompileError) lib/cantina_web/live/diner_live.ex:13: wrong params for topic :table.

  missing: [:table_id]
  unexpected: [:id]

:table is tables:<table_id>, so it takes exactly [:table_id].
:table is declared at lib/cantina/manifest.ex:11.
```

<!--
We can verify that you've passed the correct params to build the topic.
-->

---

<!-- _class: small-code -->

```elixir
# handle_broadcast :table, :served, %{order_id: id}, socket do
#   {:noreply, set_status(socket, id, :served)}
# end
```

```
** (CompileError) lib/cantina_web/live/diner_live.ex:1: CantinaWeb.DinerLive subscribes to topics with events it does not account for:

  * :table, :served

Add a `handle_broadcast` clause for each, or dismiss it explicitly:

    ignore_broadcast :table, :served
```

<!--
What if you don't handle a message on a topic? Compilation error

A recurring pattern we see these days is that tools that are good for humans are also good for LLMs. This is yet another example. This validation is useful for both human and robot.
-->

---

<!-- _class: small-code -->

```
$ mix phx.routes

  GET   /                    CantinaWeb.HomeLive nil
  GET   /t/:table_id         CantinaWeb.DinerLive nil
  GET   /kitchen/:station    CantinaWeb.StationLive nil
  GET   /expo                CantinaWeb.ExpoLive nil
  GET   /board               CantinaWeb.BoardLive nil
  ...
```

<!--
One thing we also struggled with previously was finding out where and how pub/sub was being used. Centralizing usage of pub/sub to a single module helped, but this helps a lot more.

Robots are great with grep, but we can do better than that. We already have a manifest and a boatload of macros. What if we tracked metadata about usage of pub/sub at compile time to give us something like `mix phx.routes`?
-->

---

<!-- _class: tiny-code -->

```
$ mix verified_pubsub.topics

Cantina.Manifest

:table  tables:<table_id>

Subscribes (1)
  subscribe          lib/cantina_web/live/diner_live.ex:13   CantinaWeb.DinerLive

:placed  1 broadcast, 1 handler
  broadcast          lib/cantina/orders.ex:96                Cantina.Orders
  handle_broadcast   lib/cantina_web/live/diner_live.ex:152  CantinaWeb.DinerLive

...
```

<!--
We can do that with `mix verified.pubsub.topics`
-->

---

<!-- _class: tiny-code -->

```
...

:station  stations:<station>

Subscribes (2)
  subscribe          lib/cantina_web/live/board_live.ex:20     CantinaWeb.BoardLive
  subscribe          lib/cantina_web/live/station_live.ex:30   CantinaWeb.StationLive

:claimed  1 broadcast, 1 handler, 1 ignore
  broadcast          lib/cantina/kitchen.ex:107                Cantina.Kitchen
  handle_broadcast   lib/cantina_web/live/station_live.ex:151  CantinaWeb.StationLive
  ignore_broadcast   lib/cantina_web/live/board_live.ex:190    CantinaWeb.BoardLive

...
```

<!--
This mix task gives us all the topics in the app, where they are subscribed to, and a breakdown of usage of all the messages on each topic. We can see where each message is broadcast, handled, and ignored. You and the robot don't have to grep through your code anymore. The metadata is right there.
-->

---

<!-- _class: tiny-code -->

```
$ mix verified_pubsub.topics table

Cantina.Manifest

:table  tables:<table_id>

Subscribes (1)
  subscribe          lib/cantina_web/live/diner_live.ex:13   CantinaWeb.DinerLive

:placed  1 broadcast, 1 handler
  broadcast          lib/cantina/orders.ex:96                Cantina.Orders
  handle_broadcast   lib/cantina_web/live/diner_live.ex:152  CantinaWeb.DinerLive

:ready  1 broadcast, 1 handler
  broadcast          lib/cantina/orders.ex:168               Cantina.Orders
  handle_broadcast   lib/cantina_web/live/diner_live.ex:157  CantinaWeb.DinerLive

:served  1 broadcast, 1 handler
  broadcast          lib/cantina/orders.ex:109               Cantina.Orders
  handle_broadcast   lib/cantina_web/live/diner_live.ex:161  CantinaWeb.DinerLive
```

<!--
And you can filter it as well. If you want to see all the usage of a particular topic, pass the name of the topic.
-->

---

<!-- _class: tiny-code -->

```
$ mix verified_pubsub.topics table ready

Cantina.Manifest

:table  tables:<table_id>

Subscribes (1)
  subscribe          lib/cantina_web/live/diner_live.ex:13   CantinaWeb.DinerLive

:ready  1 broadcast, 1 handler
  broadcast          lib/cantina/orders.ex:168               Cantina.Orders
  handle_broadcast   lib/cantina_web/live/diner_live.ex:157  CantinaWeb.DinerLive
```

<!--
Or you can get really fine grained and filter it by just the event on the topic as well.
-->

---

<!-- _class: tiny-code -->

```
$ mix verified_pubsub.topics table --format json

{"manifests":[{"module":"Cantina.Manifest","topics":[{"name":"table","wire":"tables:<table_id>",
"counts":{"broadcast":3,"handle":3,"ignore":0,"subscribe":1},"subscribes":[{"kind":"subscribe",
"file":"lib/cantina_web/live/diner_live.ex","line":13,"module":"CantinaWeb.DinerLive"}],"events":
[{"name":"placed","counts":{"broadcast":1,"handle":1,"ignore":0},"call_sites":[{"kind":"broadcast",
"file":"lib/cantina/orders.ex","line":96,"module":"Cantina.Orders"},{"kind":"handle","file":
"lib/cantina_web/live/diner_live.ex","line":152,"module":"CantinaWeb.DinerLive"}]},{"name":"ready",
"counts":{"broadcast":1,"handle":1,"ignore":0},"call_sites":[{"kind":"broadcast","file":
"lib/cantina/orders.ex","line":168,"module":"Cantina.Orders"},{"kind":"handle","file":
"lib/cantina_web/live/diner_live.ex","line":157,"module":"CantinaWeb.DinerLive"}]},{"name":"served",
"counts":{"broadcast":1,"handle":1,"ignore":0},"call_sites":[{"kind":"broadcast","file":
"lib/cantina/orders.ex","line":109,"module":"Cantina.Orders"},{"kind":"handle","file":
"lib/cantina_web/live/diner_live.ex","line":161,"module":"CantinaWeb.DinerLive"}]}]}]}]}
```

<!--
Or maybe you want something a little more machine readable. You can get the results as unformatted json as well. Just pipe it into jq or your favorite tool for additional munging.
-->

---

```elixir
message :placed do
  field :order_id, :string
  field :line_items, {:list, Cantina.LineItem}
end
```

<!--
Does all of this have any performance cost? At runtime, no. The only check that cannot be done at compile time is the types on fields in a message

These types must be checked at runtime. That's pretty low.
-->

---

| Scenario                                      | Plain   | Verified |
| --------------------------------------------- | ------- | -------- |
| broadcast, no subscribers, 2 fields           | 0.55 µs | 1.06 µs  |
| broadcast, no subscribers, 20 fields          | 0.55 µs | 2.45 µs  |
| round trip: broadcast, receive, handle_info/2 | 0.63 µs | 1.23 µs  |
| broadcast to 100 subscribers                  | 94 µs   | 108 µs   |
| `{:list, :string}` field, 1,000 elements      | 0.56 µs | 7.1 µs   |
| `{:list, :string}` field, 100,000 elements    | 0.53 µs | 606 µs   |

<!--
You can see here that we're talking about microseconds. Now, if you start broadasting large lists over pub/sub, that does get into hundreds of microseconds, but that is not a use case that I have seen. I haven't worked on an app that sends messages that heavy.

There is a hit on compilation times though.
-->

---

| Topics | Plain  | Verified | Manifest alone | Manifest .beam | Files recompiled by a manifest edit |
| ------ | ------ | -------- | -------------- | -------------- | ----------------------------------- |
| 20     | 0.11 s | 0.38 s   | 0.26 s         | 299 KB         | 71 (0.36 s)                         |
| 100    | 0.29 s | 4.4 s    | 3.8 s          | 1.4 MB         | 301 (4.4 s)                         |
| 250    | 0.64 s | 23.1 s   | 22.3 s         | 3.6 MB         | 751 (23.5 s)                        |

<!--
You can see the entire cost is in the manifest. Editing the manifest is going to cause a recompilation penalty. I'm fine with that tradeoff. You can also see that the performance is not good as the number of topics in a single manifest grows. The library does support multiple manifests, but we haven't gotten to the point of using that at work yet. There will probably be refinements if/when we use it.

Benchmarks like this are trivial to run now. With LLMs, there is no excuse to not be setting up benchmarks on your apps and libraries.

I told Claude I wanted run and compile time benchmarks. 15 minutes later I had benchmarks that were good enough for my purposes. It actually pushed the library way further than I think is reasonable. The first benchmarks went up to 1,000 topics. Each topic had 5 events with 5 fields each. That is a lot. Even the 250 topics I settled on for the upper bound is a lot.
-->

---

| Topics | Spark 2.7.2 .beam | Spark 2.7.9 .beam |
| ------ | ----------------- | ----------------- |
| 20     | 1.5 MB            | 299 KB            |
| 100    | 7.4 MB            | 1.4 MB            |
| 250    | 18 MB             | 3.6 MB            |

<!--
This led me to upgrade Spark because Zach Daniel had thrown the robot at Spark performance in the weeks since I had started working on the library. The big win was reducing the size of the .beam file from 18 -> 3.6 MB on the 250 topic case.
-->

---

```elixir
# Cantina.Manifest

topic :station, ["stations", :station] do
  # ...
end
```

```elixir
# Cantina.Menu

@stations [:grill, :fryer, :bar]
```

<!--
Where do we go from here? This library is in production at work. It is not being used everywhere yet. I'll continue to refine the library as I port the rest of our usage. We're consistently finding bugs and inconsistent usage as we port the legacy pub/sub. That is the part that takes the most time.

We continue to run into topics and messages with inconsistent shapes. It's very clear that there were no guiding principles here.

I expect the API to be a bit in flux as that happens. I think the core is pretty set now, but edge cases will come up that need to be addressed. For example, while putting together this demo app a case came up that we could verify at compile-time that the library didn't support yet.

This is a topic for stations in the kitchen. The list of stations is a list of atoms known at compile-time. It could be a compile-time error if you try to use value not in that list for :station. I haven't ported anything like this in our app yet, so I haven't gotten to it.
-->

---

<div class="columns">
<div>

# Brian Meeker

Engineering Manager, GetThru

<span class="accent">@brianmeeker.bsky.social</span>

</div>
<div class="center">

<img class="qr" src="images/qr-repo.svg" alt="QR code to the talk repo">

<span class="caption">github.com/CuriousCurmudgeon/ex_mex_2026_talk</span>

</div>
</div>

<!--
I really want to stress how easy it is to try out ideas like this now. It's easier than ever to create libraries like this. And it's easier than ever to fork libraries like this and customize them for your use. That doesn't come without cost, but the cost is much lower than it used to be.

Giving your robot guardrails keeps them on task. The combination of compile-time verification, usage rules, and mix tasks make it very easy for robots to use even though nothing about this library is in its training data.

Once again, I am Brian Meeker. If you want to contact me on the internet, your best bet is Bluesky. Thanks everybody for coming. Thanks to the ExMex organizer.
-->
