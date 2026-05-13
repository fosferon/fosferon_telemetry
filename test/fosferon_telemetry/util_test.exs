defmodule FosferonTelemetry.UtilTest do
  use ExUnit.Case, async: true

  alias FosferonTelemetry.Util

  describe "truncate/2" do
    test "passes short messages through unchanged" do
      assert Util.truncate("short message") == "short message"
    end

    test "truncates at default 512 bytes and appends [truncated] marker" do
      huge = String.duplicate("A", 2_000)
      truncated = Util.truncate(huge)

      assert byte_size(truncated) <= 512 + byte_size(" [truncated]")
      assert String.ends_with?(truncated, " [truncated]")
      assert String.starts_with?(truncated, String.duplicate("A", 512))
    end

    test "honors a custom max_bytes" do
      huge = String.duplicate("A", 200)
      truncated = Util.truncate(huge, 50)

      assert byte_size(truncated) <= 50 + byte_size(" [truncated]")
      assert String.starts_with?(truncated, String.duplicate("A", 50))
    end

    test "non-binary input is inspected (defensive fallback)" do
      assert Util.truncate(:some_atom) == ":some_atom"
      assert Util.truncate({:tagged, "thing"}) == "{:tagged, \"thing\"}"
    end

    test "respects UTF-8 codepoint boundaries on 3-byte sequences (curly quote)" do
      payload = String.duplicate("A", 511) <> "\u201C" <> String.duplicate("B", 600)
      truncated = Util.truncate(payload)

      assert String.valid?(truncated)
      assert String.ends_with?(truncated, " [truncated]")
    end

    test "respects UTF-8 codepoint boundaries on 4-byte sequences (emoji)" do
      payload = String.duplicate("A", 509) <> "🔥" <> String.duplicate("B", 600)
      truncated = Util.truncate(payload)

      assert String.valid?(truncated)
      assert String.ends_with?(truncated, " [truncated]")
    end
  end

  describe "safe_prefix/2" do
    test "returns the full binary when shorter than max_bytes" do
      assert Util.safe_prefix("hello", 100) == "hello"
    end

    test "trims trailing bytes until UTF-8 valid (curly quote)" do
      assert Util.safe_prefix("aaaaaaaaa\u201C", 10) == "aaaaaaaaa"
    end

    test "trims trailing bytes until UTF-8 valid (emoji)" do
      assert Util.safe_prefix("aaaaaa🔥", 9) == "aaaaaa"
    end

    test "returns empty string at max_bytes=0" do
      assert Util.safe_prefix("anything", 0) == ""
    end
  end

  describe "safe_exception_message/1" do
    test "extracts only postgres.message from Postgrex.Error (no SQL leak)" do
      err = %Postgrex.Error{
        postgres: %{
          severity: "ERROR",
          code: :undefined_table,
          message: "relation \"missing_table\" does not exist",
          pg_code: "42P01"
        },
        query: "SELECT * FROM missing_table WHERE secret_token = 'leak_me'"
      }

      result = Util.safe_exception_message(err)

      assert result == "relation \"missing_table\" does not exist"
      refute result =~ "secret_token"
      refute result =~ "SELECT"
    end

    test "handles bare-map Postgrex shape (test fixtures)" do
      assert Util.safe_exception_message(%{postgres: %{message: "boom"}}) == "boom"
    end

    test "returns bounded class name for Ecto.QueryError (query body never leaks)" do
      err = %Ecto.QueryError{message: "bad query: SELECT * FROM secret_table"}

      assert Util.safe_exception_message(err) == "Ecto.QueryError"
    end

    test "falls back to Exception.message/1 for safe exception structs" do
      err = %ArgumentError{message: "bad arg"}

      assert Util.safe_exception_message(err) == "bad arg"
    end

    test "passes through binaries unchanged" do
      assert Util.safe_exception_message("plain string reason") == "plain string reason"
    end

    test "stringifies atoms" do
      assert Util.safe_exception_message(:not_found) == "not_found"
    end

    test "inspects arbitrary terms" do
      assert Util.safe_exception_message({:tagged, "thing"}) == "{:tagged, \"thing\"}"
    end
  end
end
