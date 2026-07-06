# FosferonTelemetry

Shared failure-telemetry conventions for Elixir apps: UTF-8-safe metadata
shaping, shorthand counter generation, and a generic `:telemetry` handler for
the canonical failure-event schema.

The problem this solves: failure events are easy to emit but hard to ship
safely. A naive truncation splits a UTF-8 codepoint and breaks every
JSON-serializing consumer (Prometheus, OpenTelemetry, log shippers). A
`Postgrex.Error` or `Ecto.QueryError` happily embeds raw SQL — including bind
values — straight into your metrics pipeline. This library centralises the
defensive shaping so every app in an organisation wires the same safe
metadata before values reach a sink.

## Installation

```elixir
def deps do
  [
    {:fosferon_telemetry, "~> 0.1"}
  ]
end
```

## The canonical failure schema

Every failure event carries the same metadata shape:

| key            | type     | notes                                        |
|----------------|----------|----------------------------------------------|
| `stage`        | `atom`   | The only field safe to use as a metric **tag**. |
| `error_class`  | `atom`   | Coarse category: `:timeout`, `:db`, `:auth`, … |
| `error_message`| `string` | Bounded, sanitised — no SQL, no query AST.   |

The event-name convention is `[:<app>, <domain>, :failure]` (3-segment) — for
example `[:my_app, :checkout, :failure]`. Apps with deeper event hierarchies
can use the explicit-tuple mode of `FailureMetrics`.

## `FosferonTelemetry.Util` — safe metadata shaping

The defensive core. Use it before any value lands in telemetry metadata.

```elixir
# UTF-8-safe truncation — never splits a codepoint.
FosferonTelemetry.Util.truncate("x" <> "\u201C" <> String.duplicate("y", 1000), 64)
# => a valid UTF-8 prefix of <= 64 bytes, followed by " [truncated]"

# Exception sanitisation — never leaks SQL or query AST.
err = %Postgrex.Error{
  postgres: %{message: "relation \"users\" does not exist"},
  query: "SELECT * FROM users WHERE token = 'secret'"
}
FosferonTelemetry.Util.safe_exception_message(err)
# => "relation \"users\" does not exist"   — query body is dropped

FosferonTelemetry.Util.safe_exception_message(%Ecto.QueryError{message: "...SQL..."})
# => "Ecto.QueryError"   — the AST-bearing message is replaced wholesale
```

`safe_exception_message/1` handles `%Postgrex.Error{}` (extracts only
`postgres.message`), `%Ecto.QueryError{}` (returns the class name), other
exceptions (via `Exception.message/1`), binaries, atoms, and arbitrary terms.

## `FosferonTelemetry.FailureMetrics` — counter generation

Builds `Telemetry.Metrics.counter/2` definitions from compact input.

```elixir
# Shorthand: one app, many domains — each becomes a 3-segment failure event.
FosferonTelemetry.FailureMetrics.counters(:my_app, [:session, :checkout, :support])
# => [
#   counter("my_app.session.failure.count", tags: [:stage]),
#   counter("my_app.checkout.failure.count", tags: [:stage]),
#   counter("my_app.support.failure.count", tags: [:stage])
# ]

# Explicit tuples: for 4–5 segment event names that don't fit the shorthand.
FosferonTelemetry.FailureMetrics.counters([
  {[:billing, :invoices, :refund, :error], "billing.invoices.refund.error.count"},
  {[:billing, :invoices, :line_items, :create, :error], "billing.invoices.line_items.create.error.count"}
])
```

Hand the result to your Telemetry reporter (e.g. `telemetry_metrics_prometheus`
or `telemetry_metrics_statsd`) in your supervisor.

### Tag discipline

Counters use **only `:stage`** as a tag. Never tag on IDs, slugs, or free-text
fields — unbounded cardinality kills Prometheus. This is enforced by design in
both counter modes.

## `FosferonTelemetry.FailureHandler` — generic logger

A single `:telemetry` handler that logs every canonical failure event at
`:warning` level. Attach once per app; it survives its own crashes.

```elixir
# In Application.start/2 or a Telemetry supervisor:
FosferonTelemetry.FailureHandler.attach(:my_app, [:session, :checkout, :support])
```

Properties worth knowing:

- **Idempotent** — `:already_exists` from `:telemetry.attach_many/4` is treated
  as `:ok`, so supervision re-init and application restarts are safe.
- **Self-recovering** — the handler rescues its own exceptions so a bad event
  payload can't cause `:telemetry` to detach it. A detached handler would
  silently drop every subsequent failure event for the app.

The handler ID follows `"<app>-fosferon-failure-handler"`.

## License

MIT — see [LICENSE](LICENSE).
