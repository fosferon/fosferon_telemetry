defmodule FosferonTelemetry.FailureMetrics do
  @moduledoc """
  Generates `Telemetry.Metrics.counter/2` definitions for failure
  events.

  Two input modes cover 3-segment and 4–5 segment event names.

  ## Shorthand mode (3-segment apps)

  For apps where every failure event follows the
  `[:<app>, :<domain>, :failure]` convention:

      FosferonTelemetry.FailureMetrics.counters(:my_app, [:session, :checkout, :support])
      # => [
      #   counter("my_app.session.failure.count", tags: [:stage]),
      #   counter("my_app.checkout.failure.count", tags: [:stage]),
      #   counter("my_app.support.failure.count", tags: [:stage])
      # ]

  ## Explicit tuple mode (4–5 segment apps)

  For apps with non-standard event structures, pass a list of
  `{event_name, metric_name}` tuples:

      FosferonTelemetry.FailureMetrics.counters([
        {[:billing, :invoices, :refund, :error],
         "billing.invoices.refund.error.count"},
        {[:billing, :invoices, :line_items, :create, :error],
         "billing.invoices.line_items.create.error.count"}
      ])

  ## Tag discipline

  v1 rule: counters use only `:stage` as a tag. Never tag on IDs,
  slugs, or free-text fields — unbounded cardinality kills Prometheus.
  """

  import Telemetry.Metrics, only: [counter: 2]

  @doc """
  Generate failure counters in shorthand mode.

  Each domain atom becomes a `[:<app>, :<domain>, :failure]` event
  with metric name `"<app>.<domain>.failure.count"`.
  """
  @spec counters(atom(), [atom()]) :: [Telemetry.Metrics.Counter.t()]
  def counters(app, domains) when is_atom(app) and is_list(domains) do
    Enum.map(domains, fn domain ->
      event_name = "#{app}.#{domain}.failure.count"
      counter(event_name, tags: [:stage], event_name: [app, domain, :failure])
    end)
  end

  @doc """
  Generate failure counters in explicit tuple mode.

  Each `{event_name, metric_name}` tuple maps directly to a counter
  definition. Use this for apps whose event names don't follow the
  3-segment `[:<app>, :<domain>, :failure]` convention.
  """
  @spec counters([{[atom()], String.t()}]) :: [Telemetry.Metrics.Counter.t()]
  def counters(tuples) when is_list(tuples) do
    Enum.map(tuples, fn {event_name, metric_name} ->
      counter(metric_name, tags: [:stage], event_name: event_name)
    end)
  end
end
