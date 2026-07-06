defmodule FosferonTelemetry.FailureHandler do
  @moduledoc """
  Generic `:telemetry` handler for apps whose failure events follow the
  canonical metadata schema: `stage`, `error_class`, `error_message`.

  Scoped to 3-segment failure events (`[:<app>, :<domain>, :failure]`).

  ## Usage

      # In your Application.start/2 or a Telemetry supervisor:
      FosferonTelemetry.FailureHandler.attach(:my_app, [:session, :checkout, :support])

  This attaches a single handler via `:telemetry.attach_many/4` that
  logs all matching events at `:warning` level with the canonical
  metadata fields.

  ## Idempotency

  `attach/2` is idempotent — `:already_exists` from
  `:telemetry.attach_many/4` is treated as `:ok`, so application
  restarts and supervision re-init are safe.

  ## Self-recovery

  The handler rescues its own exceptions to prevent `:telemetry` from
  detaching it on crash. A crashing handler would silently drop all
  subsequent failure events for the app.
  """

  require Logger

  @doc """
  Attach this handler for the given `app` and `domains`.

  Builds events as `[:<app>, :<domain>, :failure]` for each domain,
  then attaches a single handler via `:telemetry.attach_many/4`.

  The handler ID follows the convention
  `"<app>-fosferon-failure-handler"`.
  """
  @spec attach(atom(), [atom()]) :: :ok
  def attach(app, domains) when is_atom(app) and is_list(domains) do
    handler_id = "#{app}-fosferon-failure-handler"

    events = Enum.map(domains, fn domain -> [app, domain, :failure] end)

    case :telemetry.attach_many(
           handler_id,
           events,
           &__MODULE__.handle_event/4,
           %{app: app}
         ) do
      :ok -> :ok
      {:error, :already_exists} -> :ok
    end
  end

  @doc false
  def handle_event([app, domain, :failure], _measurements, metadata, _config) do
    Logger.warning(
      "[#{app}:#{domain}:failure] stage=#{metadata.stage} " <>
        "error=#{inspect(metadata.error_class)} " <>
        "message=#{inspect(metadata.error_message)}"
    )
  rescue
    e ->
      Logger.error(
        "[FosferonTelemetry.FailureHandler] Handler error on " <>
          "#{inspect([app, domain, :failure])}: #{Exception.message(e)}"
      )
  end
end
