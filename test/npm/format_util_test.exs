defmodule NPM.FormatUtilTest do
  use ExUnit.Case, async: true

  describe "format_size/1" do
    test "formats bytes" do
      assert NPM.FormatUtil.format_size(0) == "0 B"
      assert NPM.FormatUtil.format_size(1023) == "1023 B"
    end

    test "formats larger units" do
      assert NPM.FormatUtil.format_size(1024) == "1.0 KB"
      assert NPM.FormatUtil.format_size(1_048_576) == "1.0 MB"
      assert NPM.FormatUtil.format_size(1_073_741_824) == "1.0 GB"
    end
  end
end
