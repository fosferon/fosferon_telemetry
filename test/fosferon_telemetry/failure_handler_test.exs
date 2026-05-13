defmodule FosferonTelemetry.FailureHandlerTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias FosferonTelemetry.FailureHandler

  @test_app :ft_test
  @handler_id "ft_test-fosferon-failure-handler"

  setup do
    :telemetry.detach(@handler_id)
    :ok
  rescue
    _ -> :ok
  end

  describe "attach/2" do
    test "attaches handler for given domains" do
      assert :ok = FailureHandler.attach(@test_app, [:session, :chat])

      handlers = :telemetry.list_handlers([@test_app, :session, :failure])
      assert Enum.any?(handlers, &(&1.id == @handler_id))
    end

    test "idempotent — second attach returns :ok" do
      assert :ok = FailureHandler.attach(@test_app, [:session])
      assert :ok = FailureHandler.attach(@test_app, [:session])
    end
  end

  describe "handle_event/4" do
    test "logs on canonical-schema event" do
      FailureHandler.attach(@test_app, [:session])

      log =
        capture_log(fn ->
          :telemetry.execute(
            [@test_app, :session, :failure],
            %{count: 1},
            %{stage: :init, error_class: :timeout, error_message: "timed out"}
          )
        end)

      assert log =~ "ft_test:session:failure"
      assert log =~ "stage=init"
      assert log =~ ":timeout"
      assert log =~ "timed out"
    end

    test "rescue self-recovery — handler survives bad metadata" do
      FailureHandler.attach(@test_app, [:chat])

      log =
        capture_log(fn ->
          :telemetry.execute(
            [@test_app, :chat, :failure],
            %{count: 1},
            %{}
          )
        end)

      assert log =~ "[FosferonTelemetry.FailureHandler] Handler error"

      # Handler must still be attached after the rescue
      handlers = :telemetry.list_handlers([@test_app, :chat, :failure])
      assert Enum.any?(handlers, &(&1.id == @handler_id))
    end
  end
end
