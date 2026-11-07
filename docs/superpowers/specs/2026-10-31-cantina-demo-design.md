Cantina demo app
================

Cantina is the demo app for the VerifiedPubSub talk at ExMex. It runs a Tex-Mex restaurant during service. The
audience orders food from their phones. Volunteer cooks work the kitchen screens. The projector shows the whole
kitchen.

> **On the `organized-pubsub` branch:** the app has no VerifiedPubSub. `Cantina.PubSub` holds each topic and each
> message, organized by topic: a `subscribe_*` function for each topic and a `broadcast_*` function for each message.
> Each message is `{event, payload_map}`. The behavior is the same as on `main`. The branch is the middle picture:
> plain `Phoenix.PubSub`, but organized. It branches from `messy-pubsub`, the "before" picture, where each call site
> calls `Phoenix.PubSub` itself.

The demo shows these features of VerifiedPubSub:

- Topics with params, as `["tables", :table_id]` and `["stations", :station]`.
- One event that many subscribers receive, and one screen that collects events from many topics.
- Payload fields with struct types and primitive types.
- `broadcast_from!` for many cooks at one station.
- A compile error for each typo in a topic, a param, an event, or a payload field.
- A compile error in each subscriber when an event is new and the subscriber does not handle it.
- `mix verified_pubsub.topics` and the generated `## Topics` docs.
- Plain `Phoenix.PubSub` topics for Presence next to the manifest.

## Kitchen terms

| Term | Meaning | In the app |
|---|---|---|
| Ticket | The list of items that one station cooks for one order | `Cantina.Ticket` |
| Station | One area of the kitchen: grill, fryer, or bar | the `:station` param |
| Fire | Tell a station to start an item | `:fired` |
| Claim | A cook takes a ticket, so that no other cook starts it | `:claimed` |
| Bump | Mark a ticket done on the kitchen screen | `:bumped` |
| Expo | The expediter. This person collects the tickets of an order and sends the order out complete. | `/expo` |
| The pass | The counter where finished plates wait for the expediter | the expo screen |
| Run | Carry the food to the table | `:served` |
| KDS | Kitchen display system: the screen at a station | `/kitchen/:station` |

## Scope

In scope:

- One Phoenix app with LiveView. It runs on one node.
- State in memory. A restart clears all orders.
- No authentication. The URL gives the table or the station.

Out of scope:

- A database. The talk is about PubSub, and a database is one more part that can fail on stage.
- Payment, a check, or a bill.
- A cluster of many nodes. The state lives in GenServers on one node.

## Flow

```
diner phone ──places an order──▶ Cantina.Orders
                                   │ splits the order into one ticket for each station
                                   ├─▶ :station (grill)   :fired
                                   ├─▶ :station (fryer)   :fired
                                   ├─▶ :station (bar)     :fired
                                   └─▶ :table (table_id)  :placed

cook claims a ticket ──▶ :station  :claimed    (the screens of other cooks lock the card)
cook leaves          ──▶ :station  :released   (the card unlocks)
cook bumps a ticket  ──▶ :station  :bumped     (broadcast_from!, the other screens drop the card)
                     └─▶ :expo     :ticket_ready
each ticket is ready ──▶ :expo     :order_complete
                     └─▶ :table    :ready
expo runs the order  ──▶ :table    :served
                     └─▶ :expo     :served          (added on stage)

manager              ──▶ :menu     :special_added
```

## Manifest

```elixir
defmodule Cantina.Topics do
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

  topic :station, ["stations", :station] do
    description "The tickets of one kitchen station: grill, fryer, or bar."

    message :fired do
      field :ticket, Cantina.Ticket
    end

    message :claimed do
      field :ticket_id, :string
      field :cook_name, :string
    end

    message :released do
      description "The cook of the ticket left the station."
      field :ticket_id, :string
    end

    message :bumped do
      field :ticket_id, :string
      field :cook_seconds, :integer
    end
  end

  topic :expo, ["expo"] do
    description "Tickets that are ready to plate and run."

    message :ticket_ready do
      field :ticket, Cantina.Ticket
    end

    message :order_complete do
      field :order_id, :string
      field :table_id, :string
    end
  end

  topic :menu, ["menu"] do
    description "Changes to the menu during service."

    message :special_added do
      field :item, Cantina.MenuItem
      field :note, :string, required: false
    end
  end
end
```

`:served` on the `:expo` topic stays out of the first build. The talk adds it live. See [Demo beats](#demo-beats).

## Structs

- `Cantina.MenuItem`: `id`, `name`, `station`, `price_cents`, `available?`
- `Cantina.LineItem`: `menu_item_id`, `name`, `quantity`, `note`
- `Cantina.Ticket`: `id`, `order_id`, `table_id`, `station`, `line_items`, `fired_at`, `claimed_by`

## Menu

| Station | Items |
|---|---|
| `:grill` | Carne asada tacos, al pastor tacos, chicken fajitas, cheese quesadilla |
| `:fryer` | Chips and guac, chips and queso, flautas, churros |
| `:bar` | Margarita, horchata, Mexican Coke, agua fresca |

## Modules

| Module | Kind | Job |
|---|---|---|
| `Cantina.Topics` | Manifest | Declares each topic and event. |
| `Cantina.Menu` | Context and `Agent` | Holds the menu. Adds a special. |
| `Cantina.Orders` | Context and `GenServer` | Places an order. Splits it into tickets. Tracks when each order is complete. Marks an order served. |
| `Cantina.Kitchen` | Context and `GenServer` | Holds the open tickets of each station. Claims, releases, and bumps a ticket. Monitors the process of each cook. |
| `Cantina.Rush` | `GenServer` | Places random orders, and bumps a ticket that waits too long. The board starts and stops it. |
| `Cantina.Presence` | `Phoenix.Presence` | Tracks diners and cooks. |

Each context broadcasts. A LiveView calls a context and does not broadcast itself. Then a slide can show the
broadcasts of one feature in one module.

### Claim lock

- A ticket has at most one cook. `Cantina.Kitchen.claim/3` returns `{:error, :taken}` when another cook holds it.
- Only the cook that holds the ticket can bump it.
- `Cantina.Kitchen` monitors the LiveView process of each cook with a claim. When that process exits, the server
  releases each ticket of that cook and broadcasts `:released`.
- `Cantina.Kitchen` bumps a ticket itself after about 45 seconds, claimed or not. The auto-bump stops a distracted
  volunteer from stalling the demo. Then `:bumped` comes from the server, and each cook screen drops the card.

### Presence

Presence uses its own topics: `"presence:diners"` and `"presence:cooks"`. The manifest does not declare them. A
LiveView receives `presence_diff` in a plain `handle_info/2`. A slide shows that VerifiedPubSub lives next to plain
`Phoenix.PubSub` topics.

## Screens

| Route | Who | Subscribes to | Calls |
|---|---|---|---|
| `/` | Each guest, from the QR code | `"presence:cooks"` | Picks a job: a table, a station, or expo. |
| `/t/:table_id` | A diner | `:table` for the table, `:menu` | `Orders.place/2` |
| `/kitchen/:station` | A cook | `:station` for the station, `:menu` | `Kitchen.claim/3`, `Kitchen.bump/3` |
| `/expo` | The expediter | `:expo` | `Orders.serve/1` |
| `/board` | The projector | `:expo`, `:menu`, `:station` for each station, both Presence topics | `Menu.add_special/2`, `Rush.start/0`, `Rush.stop/0` |

### Diner, `/t/:table_id`

- The header shows the table, as "Table 42".
- The menu lists each item with a quantity stepper and an order button.
- Below the menu, each order shows its status: placed, then ready, then served.

### Home, `/`

- "Grab a table" sends the guest to a random table, `/t/:table_id`.
- "Work the kitchen" lists the stations. Each station shows its count of cooks from Presence.
- A station shows "kitchen full" when it has the maximum count of cooks. The default maximum is 3.
- The cook enters a name, or the app gives one, as "Cook 3".
- "Run expo" sends the guest to `/expo`. Any number of guests can run expo.

### Station, `/kitchen/:station`

- Each open ticket is a card. The card is green when it is new, yellow after 20 seconds, and red after 40 seconds.
- An open card has a "Claim" button. A card that another cook holds shows "Taken by Cook 3" and has no button.
- A card that this cook holds has a "Bump" button.

### Expo, `/expo`

- Each order is a card that lists its stations. A station gets a check mark when its ticket is ready.
- A complete order shows a "Run it" button.
- After the live change, a served order leaves each expo screen. Before it, the card leaves only the screen that ran it.

### Board, `/board`

- The counts from Presence, as "37 diners seated · 4 cooks on the line".
- The count of open tickets at each station, and the average of `cook_seconds`.
- A feed of the last orders. A ready order shows "at the pass", and a served order shows "served". Before the live
  change, the board does not hear `:served`, so a run order keeps "at the pass" until the board reloads.
- The manager controls:
  - Add a special.
  - Start or stop the rush.

## Demo beats

1. Show the QR code for `/`. The audience picks a job. Diners order, and the board fills.
2. Ask for volunteers to pick a station or expo on the same page. Show the claim lock and the bump on the projector.
3. Typo in a topic: `broadcast!(:stations, ...)` in `Cantina.Kitchen` does not compile.
4. Typo in a param: `%{station_id: :grill}` does not compile.
5. Typo in a payload field: `cook_secs` does not compile.
6. Fix a bug: the board shows a run order "at the pass", and a second expo screen keeps its card. Add `:served` with
   an `:order_id` field to `:expo`. Two LiveViews then do not compile, one at a time:
   - The board handles it and marks the order served.
   - The expo screen handles it and drops the card.
7. Run `mix verified_pubsub.topics expo served`. It shows two handlers and `(no broadcast)`. Then add
   `broadcast!(:expo, :served, ...)` to `Orders.serve/1`, and run the task again.
8. Open the generated `## Topics` docs of `Cantina.Topics`.

Keep the change for each live beat on its own git branch, named `beat/NN-name` with the number of the beat, as
`beat/06-expo-served`. When the live typing goes wrong, check out the branch.

## Risks

- Bad wifi. `Cantina.Rush` fills the kitchen without phones, and the auto-bump empties it without cooks.
- Too many cooks. The cap on each station keeps most of the audience on the diner screen.
- A crash in a GenServer clears the state. The supervisor restarts it with empty state, and the rush fills it again.
- One node. Deploy one machine, so that the GenServers and Presence see the same state.

## Features to cut for live code

The first build has each feature. Before the talk, pick features to remove and then add live. These features fit:

- The claim lock: the `:claimed` and `:released` events.
- `:special_added`.
- The `broadcast_from!` in `Kitchen.bump/3`.
