defmodule FosferonTelemetry.FailureMetricsTest do
  use ExUnit.Case, async: true

  alias FosferonTelemetry.FailureMetrics

  describe "counters/2 (shorthand mode)" do
    test "generates correct counters for each domain" do
      counters = FailureMetrics.counters(:atrapos, [:session, :chat, :workbench])

      assert length(counters) == 3

      [session, chat, workbench] = counters

      assert session.name == [:atrapos, :session, :failure, :count]
      assert session.event_name == [:atrapos, :session, :failure]
      assert session.tags == [:stage]

      assert chat.name == [:atrapos, :chat, :failure, :count]
      assert chat.event_name == [:atrapos, :chat, :failure]
      assert chat.tags == [:stage]

      assert workbench.name == [:atrapos, :workbench, :failure, :count]
      assert workbench.event_name == [:atrapos, :workbench, :failure]
      assert workbench.tags == [:stage]
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
          {[:mobus_core, :tenants, :provision, :error],
           "mobus_core.tenants.provision.error.count"},
          {[:mobus_core, :tenants, :schema, :create, :error],
           "mobus_core.tenants.schema.create.error.count"}
        ])

      assert length(counters) == 2

      [provision, schema_create] = counters

      assert provision.name == [:mobus_core, :tenants, :provision, :error, :count]
      assert provision.event_name == [:mobus_core, :tenants, :provision, :error]
      assert provision.tags == [:stage]

      assert schema_create.name == [:mobus_core, :tenants, :schema, :create, :error, :count]

      assert schema_create.event_name == [
               :mobus_core,
               :tenants,
               :schema,
               :create,
               :error
             ]

      assert schema_create.tags == [:stage]
    end

    test "returns empty list for empty tuples" do
      assert FailureMetrics.counters([]) == []
    end
  end
end
