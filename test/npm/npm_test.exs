defmodule NPM.TopLevelAPITest do
  @moduledoc false
  use ExUnit.Case, async: true

  describe "NPM module public API" do
    test "exports install functions" do
      funs = NPM.__info__(:functions)
      assert {:install, 0} in funs
      assert {:install, 1} in funs
    end

    test "exports add/remove functions" do
      funs = NPM.__info__(:functions)
      assert {:add, 1} in funs
      assert {:add, 2} in funs
      assert {:add, 3} in funs
      assert {:remove, 1} in funs
    end

    test "exports list/get/update functions" do
      funs = NPM.__info__(:functions)
      assert {:list, 0} in funs
      assert {:get, 0} in funs
      assert {:update, 0} in funs
      assert {:update, 1} in funs
    end
  end
end
