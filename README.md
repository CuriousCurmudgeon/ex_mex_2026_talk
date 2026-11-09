# Preventing Pub/Sub Spaghetti in Event-Driven Systems

A talk by Brian Meeker at [ExMex 2026](https://exmexconf.com), a single-track Elixir
conference held November 12–13, 2026 at Capital Factory in Austin, Texas.

The talk covers what you get out of the box with Phoenix PubSub, the messes you can make
with it, and how to layer compile-time guarantees on top of it with
[verified_pubsub](https://github.com/CuriousCurmudgeon/verified_pubsub)
([Hex](https://hex.pm/packages/verified_pubsub)).

## TexMex, the demo app

The code examples in the talk come from TexMex, a demo app for a Tex Mex restaurant.
Diners place orders from their phones, and pub/sub carries each order to the kitchen
stations and back. It is hosted at [texmex.fly.dev](https://texmex.fly.dev).

The app shows three stages of the same pub/sub code, one per branch:

- `messy-pubsub`: every module calls `Phoenix.PubSub` directly.
- `organized-pubsub`: broadcasts and subscriptions go through helper functions in
  `Cantina.PubSub`.
- `main`: topics and events are declared in a verified_pubsub manifest, `Cantina.Manifest`.

It is a standard Phoenix app: `mix setup`, then `mix phx.server`.

## Slides

The slides are in `presentation/`, written in [Marp](https://marp.app). Marp only reads
its config from the directory it runs in, so run it from there:

```sh
cd presentation
marp -s .
```
