defmodule FosferonTelemetry do
  @moduledoc """
  Shared failure-telemetry conventions for Fosferon Elixir apps.

  Three modules:

    * `FosferonTelemetry.Util` — UTF-8-safe truncation and exception
      sanitization for telemetry metadata values.
    * `FosferonTelemetry.FailureMetrics` — generates
      `Telemetry.Metrics.counter/2` definitions from shorthand or
      explicit event-name tuples.
    * `FosferonTelemetry.FailureHandler` — generic `:telemetry` handler
      for apps whose failure events follow the canonical metadata
      schema (`stage`, `error_class`, `error_message`).
  """
end
