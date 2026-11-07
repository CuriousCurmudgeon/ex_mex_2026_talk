defmodule Cantina.Manifest do
  @moduledoc """
  Each topic and event of Cantina.

  Presence uses its own topics, `"presence:diners"` and `"presence:cooks"`. They stay out
  of this manifest.
  """

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
