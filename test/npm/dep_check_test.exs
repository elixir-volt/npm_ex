defmodule NPM.DepCheckTest do
  use ExUnit.Case, async: true

  describe "extract_imports from source" do
    test "require statements" do
      source = ~s[const lodash = require('lodash')]
      assert "lodash" in NPM.DepCheck.extract_imports(source)
    end

    test "import statements" do
      source = ~s[import React from 'react']
      assert "react" in NPM.DepCheck.extract_imports(source)
    end

    test "named imports" do
      source = ~s[import { useState, useEffect } from 'react']
      assert "react" in NPM.DepCheck.extract_imports(source)
    end

    test "dynamic imports" do
      source = ~s[const mod = import('lodash')]
      assert "lodash" in NPM.DepCheck.extract_imports(source)
    end

    test "export from" do
      source = ~s[export { default } from 'react-dom']
      assert "react-dom" in NPM.DepCheck.extract_imports(source)
    end

    test "skips relative imports" do
      source = """
      import utils from './utils'
      import helper from '../helper'
      const config = require('./config')
      """

      assert NPM.DepCheck.extract_imports(source) == []
    end

    test "scoped packages" do
      source = ~s[import core from '@babel/core']
      assert "@babel/core" in NPM.DepCheck.extract_imports(source)
    end

    test "deep imports normalized to package name" do
      source = ~s[import cloneDeep from 'lodash/cloneDeep']
      assert "lodash" in NPM.DepCheck.extract_imports(source)
    end

    test "scoped deep imports" do
      source = ~s[import preset from '@babel/preset-env/lib/index']
      assert "@babel/preset-env" in NPM.DepCheck.extract_imports(source)
    end

    test "multiple imports deduped" do
      source = """
      import React from 'react'
      import { useState } from 'react'
      const ReactDOM = require('react-dom')
      """

      imports = NPM.DepCheck.extract_imports(source)
      assert "react" in imports
      assert "react-dom" in imports
      assert Enum.count(imports, &(&1 == "react")) == 1
    end
  end

  describe "normalize_package_name" do
    test "regular package" do
      assert "lodash" = NPM.DepCheck.normalize_package_name("lodash")
    end

    test "deep import" do
      assert "lodash" = NPM.DepCheck.normalize_package_name("lodash/cloneDeep")
    end

    test "scoped package" do
      assert "@babel/core" = NPM.DepCheck.normalize_package_name("@babel/core")
    end

    test "scoped deep import" do
      assert "@babel/core" = NPM.DepCheck.normalize_package_name("@babel/core/lib/index")
    end
  end

  describe "check project" do
    @tag :tmp_dir
    test "finds unused dependencies", %{tmp_dir: dir} do
      File.write!(
        Path.join(dir, "package.json"),
        ~s({"dependencies":{"lodash":"^4","unused-pkg":"^1"}})
      )

      File.mkdir_p!(Path.join(dir, "src"))
      File.write!(Path.join([dir, "src", "index.js"]), ~s[const _ = require('lodash')])

      {:ok, result} = NPM.DepCheck.check(dir)
      assert "unused-pkg" in result.unused
      refute "lodash" in result.unused
    end

    @tag :tmp_dir
    test "finds missing dependencies", %{tmp_dir: dir} do
      File.write!(Path.join(dir, "package.json"), ~s({"dependencies":{"lodash":"^4"}}))
      File.mkdir_p!(Path.join(dir, "src"))

      File.write!(
        Path.join([dir, "src", "index.js"]),
        ~s[const _ = require('lodash')
const axios = require('axios')]
      )

      {:ok, result} = NPM.DepCheck.check(dir)
      assert "axios" in result.missing
      refute "lodash" in result.missing
    end

    @tag :tmp_dir
    test "ignores node builtins", %{tmp_dir: dir} do
      File.write!(Path.join(dir, "package.json"), ~s({"dependencies":{}}))
      File.mkdir_p!(Path.join(dir, "src"))
      File.write!(Path.join([dir, "src", "index.js"]), ~s[const fs = require('fs')
const path = require('path')])

      {:ok, result} = NPM.DepCheck.check(dir)
      refute "fs" in result.missing
      refute "path" in result.missing
    end

    test "returns error for missing package.json" do
      assert {:error, :enoent} =
               NPM.DepCheck.check("/tmp/nonexistent_#{System.unique_integer([:positive])}")
    end
  end

  describe "scan_imports" do
    @tag :tmp_dir
    test "scans src directory", %{tmp_dir: dir} do
      File.mkdir_p!(Path.join(dir, "src"))
      File.write!(Path.join([dir, "src", "app.ts"]), ~s[import express from 'express'])

      imports = NPM.DepCheck.scan_imports(dir)
      assert MapSet.member?(imports, "express")
    end

    @tag :tmp_dir
    test "scans nested directories", %{tmp_dir: dir} do
      File.mkdir_p!(Path.join([dir, "src", "components"]))

      File.write!(
        Path.join([dir, "src", "components", "Button.tsx"]),
        ~s[import React from 'react']
      )

      imports = NPM.DepCheck.scan_imports(dir)
      assert MapSet.member?(imports, "react")
    end

    @tag :tmp_dir
    test "skips non-js files", %{tmp_dir: dir} do
      File.mkdir_p!(Path.join(dir, "src"))
      File.write!(Path.join([dir, "src", "data.json"]), ~s({"key": "value"}))
      File.write!(Path.join([dir, "src", "style.css"]), "body { color: red }")

      imports = NPM.DepCheck.scan_imports(dir)
      assert MapSet.size(imports) == 0
    end
  end

  describe "extract_imports edge cases" do
    test "empty source" do
      assert [] = NPM.DepCheck.extract_imports("")
    end

    test "double-quoted imports" do
      source = ~s[import React from "react"]
      assert "react" in NPM.DepCheck.extract_imports(source)
    end

    test "require with double quotes" do
      source = ~s[const _ = require("lodash")]
      assert "lodash" in NPM.DepCheck.extract_imports(source)
    end
  end

  describe "normalize_package_name edge cases" do
    test "single-word package" do
      assert "react" = NPM.DepCheck.normalize_package_name("react")
    end

    test "package with many slashes" do
      assert "lodash" = NPM.DepCheck.normalize_package_name("lodash/fp/get")
    end
  end
end
