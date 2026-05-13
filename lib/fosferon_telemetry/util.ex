defmodule FosferonTelemetry.Util do
  @moduledoc """
  Shared utilities for failure-telemetry emitters across Fosferon apps.

  Centralises UTF-8-safe truncation and exception sanitization so every
  app wires the same safe-metadata shape before values reach Prometheus,
  OTEL, or log-shipper sinks.

  ## Truncation

  `truncate/2` bounds `error_message` metadata to 512 bytes (default),
  respecting UTF-8 codepoint boundaries. A naive `binary_part/3` cut
  mid-codepoint produces invalid UTF-8 that breaks JSON-serializing
  telemetry consumers. `safe_prefix/2` recursively trims trailing bytes
  until `String.valid?/1` returns true — bounded by 3 iterations for
  valid UTF-8 (sequences are <= 4 bytes).

  ## Exception sanitization

  `safe_exception_message/1` extracts a bounded, query-free message
  from arbitrary exception terms. It prevents SQL and query-text leaks
  from `Postgrex.Error` and `Ecto.QueryError` which embed raw queries
  in their `message/1` output.
  """

  @default_max_bytes 512

  @doc """
  Truncate `message` to at most `max_bytes` (default 512) bytes,
  respecting UTF-8 codepoint boundaries.

  Appends `" [truncated]"` when truncation occurs. Non-binary inputs
  fall through to `inspect/1` as a defensive shim.
  """
  @spec truncate(String.t() | term(), non_neg_integer()) :: String.t()
  def truncate(message, max_bytes \\ @default_max_bytes)

  def truncate(message, max_bytes) when is_binary(message) and is_integer(max_bytes) do
    if byte_size(message) > max_bytes do
      safe_prefix(message, max_bytes) <> " [truncated]"
    else
      message
    end
  end

  def truncate(other, _max_bytes), do: inspect(other)

  @doc """
  Returns the longest valid-UTF-8 prefix of `binary` whose byte length
  is at most `max_bytes`.

  Clamps `max_bytes` to `byte_size(binary)` so callers passing a cap
  larger than the binary get the whole binary back.
  """
  @spec safe_prefix(binary(), non_neg_integer()) :: String.t()
  def safe_prefix(binary, max_bytes) when is_binary(binary) and max_bytes >= 0 do
    effective = min(max_bytes, byte_size(binary))
    candidate = binary_part(binary, 0, effective)

    if String.valid?(candidate) do
      candidate
    else
      safe_prefix(binary, effective - 1)
    end
  end

  @doc """
  Sanitize an exception or arbitrary error reason for telemetry
  metadata. Never leaks raw SQL or embedded query text.

  Handles:
    * `%Postgrex.Error{}` — extracts only `postgres.message`
    * `%Ecto.QueryError{}` — returns `"Ecto.QueryError"` (the
      pre-formatted `:message` field embeds the query AST)
    * Other exception structs — delegates to `Exception.message/1`
    * Binaries — passed through
    * Atoms — converted via `Atom.to_string/1`
    * Everything else — `inspect/1`
  """
  @spec safe_exception_message(term()) :: String.t()
  def safe_exception_message(%{postgres: %{message: msg}}) when is_binary(msg), do: msg

  def safe_exception_message(%{__struct__: Ecto.QueryError}), do: "Ecto.QueryError"

  def safe_exception_message(%{__exception__: true} = exception),
    do: Exception.message(exception)

  def safe_exception_message(reason) when is_binary(reason), do: reason
  def safe_exception_message(reason) when is_atom(reason), do: Atom.to_string(reason)
  def safe_exception_message(reason), do: inspect(reason)
end
