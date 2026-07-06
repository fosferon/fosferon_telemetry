defmodule FosferonTelemetry.FailureMetricsTest do
  use ExUnit.Case, async: true

  alias FosferonTelemetry.FailureMetrics

  describe "counters/2 (shorthand mode)" do
    test "generates correct counters for each domain" do
      counters = FailureMetrics.counters(:my_app, [:session, :checkout, :support])

      assert length(counters) == 3

      [session, checkout, support] = counters

      assert session.name == [:my_app, :session, :failure, :count]
      assert session.event_name == [:my_app, :session, :failure]
      assert session.tags == [:stage]

      assert checkout.name == [:my_app, :checkout, :failure, :count]
      assert checkout.event_name == [:my_app, :checkout, :failure]
      assert checkout.tags == [:stage]

      assert support.name == [:my_app, :support, :failure, :count]
      assert support.event_name == [:my_app, :support, :failure]
      assert support.tags == [:stage]
    end

    test "returns empty list for empty domains" do
      assert FailureMetrics.counters(:myapp, []) == []
    end

    test "tag set limited to [:stage] only" do
      [counter] = FailureMetrics.counters(:myapp, [:domain])

      assert counter.tags == [:stage]
    end
  end

  describe "counters/1 (explicit tuple mode)" do
    test "generates correct counters for explicit tuples" do
      counters =
        FailureMetrics.counters([
          {[:billing, :invoices, :refund, :error],
           "billing.invoices.refund.error.count"},
          {[:billing, :invoices, :line_items, :create, :error],
           "billing.invoices.line_items.create.error.count"}
        ])

      assert length(counters) == 2

      [refund, line_item_create] = counters

      assert refund.name == [:billing, :invoices, :refund, :error, :count]
      assert refund.event_name == [:billing, :invoices, :refund, :error]
      assert refund.tags == [:stage]

      assert line_item_create.name == [:billing, :invoices, :line_items, :create, :error, :count]

      assert line_item_create.event_name == [
               :billing,
               :invoices,
               :line_items,
               :create,
               :error
             ]

      assert line_item_create.tags == [:stage]
    end

    test "returns empty list for empty tuples" do
      assert FailureMetrics.counters([]) == []
    end
  end
end
