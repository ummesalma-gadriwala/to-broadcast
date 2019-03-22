# TOBroadcast

**Simulating the totally ordered broadcast functionality for asynchronous point-to-point message passing. The implementation includes keeping messages that are not yet ready to be to-bcast-received in a pending set, keeping track of timestamp estimates in ts and sending ts-up messages when needed.**

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `to_broadcast` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:to_broadcast, "~> 0.1.0"}
  ]
end
```