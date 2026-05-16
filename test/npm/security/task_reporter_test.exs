defmodule NPM.Security.TaskReporterTest do
  use ExUnit.Case, async: false

  alias NPM.Security.TaskReporter

  describe "parse_format/1" do
    test "parses supported formats" do
      assert TaskReporter.parse_format(nil) == {:ok, :text}
      assert TaskReporter.parse_format("text") == {:ok, :text}
      assert TaskReporter.parse_format("json") == {:ok, :json}
      assert TaskReporter.parse_format("yaml") == :error
    end
  end

  describe "parse_policy/1" do
    test "parses explicit policies" do
      assert TaskReporter.parse_policy("error") == {:ok, :error}
      assert TaskReporter.parse_policy("warn") == {:ok, :warn}
      assert TaskReporter.parse_policy("off") == {:ok, :off}
      assert TaskReporter.parse_policy("nope") == :error
    end
  end

  describe "enforce/2" do
    test "allows empty findings and non-error policies" do
      assert TaskReporter.enforce([], :error) == :ok
      assert TaskReporter.enforce([%{}], :warn) == :ok
      assert TaskReporter.enforce([%{}], :off) == :ok
    end

    test "raises for error policy with findings" do
      assert_raise Mix.Error, "Found 1 compromised packages", fn ->
        TaskReporter.enforce([%{}], :error)
      end
    end
  end
end
