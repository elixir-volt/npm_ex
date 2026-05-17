defmodule NPM.Node.RunnerTest do
  use ExUnit.Case, async: true

  alias NPM.Node.Runner

  @tag :tmp_dir
  test "runs cached esm cli with dependency resolved from project node_modules", %{tmp_dir: dir} do
    cli_dir = Path.join(dir, "cache/pkg/1.0.0")
    dep_dir = Path.join(dir, "node_modules/dep")

    File.mkdir_p!(Path.join(cli_dir, "dist"))
    File.mkdir_p!(dep_dir)

    File.write!(
      Path.join(cli_dir, "dist/cli.mjs"),
      "import value from 'dep'; console.log(value)"
    )

    File.write!(
      Path.join(dep_dir, "package.json"),
      ~s({"name":"dep","type":"module","exports":"./index.js"})
    )

    File.write!(Path.join(dep_dir, "index.js"), "export default 'ok'")

    {output, status} =
      Runner.run(Path.join(cli_dir, "dist/cli.mjs"), [],
        node_modules_dir: Path.join(dir, "node_modules"),
        cd: dir
      )

    assert status == 0, output
    assert output =~ "ok"
  end

  @tag :tmp_dir
  test "runs native binary directly without node wrapper", %{tmp_dir: dir} do
    bin_dir = Path.join(dir, "node_modules/.bin")
    pkg_dir = Path.join(dir, "node_modules/mypkg")
    File.mkdir_p!(bin_dir)
    File.mkdir_p!(pkg_dir)

    native = Path.join(pkg_dir, "native_bin")
    File.write!(native, "#!/bin/sh\necho native-ok")
    File.chmod!(native, 0o755)
    File.ln_s!(native, Path.join(bin_dir, "mypkg"))

    {output, status} =
      Runner.run(Path.join(bin_dir, "mypkg"), [],
        node_modules_dir: Path.join(dir, "node_modules"),
        cd: dir
      )

    assert status == 0, output
    assert output =~ "native-ok"
  end

  @tag :tmp_dir
  test "runs package JS scripts with node so #imports resolve", %{tmp_dir: dir} do
    pkg_dir = Path.join(dir, "node_modules/mypkg")
    bin_dir = Path.join(dir, "node_modules/.bin")
    File.mkdir_p!(pkg_dir)
    File.mkdir_p!(bin_dir)

    File.write!(
      Path.join(pkg_dir, "package.json"),
      ~s({"name":"mypkg","type":"module","imports":{"#greeting":"./greeting.js"},"bin":{"mypkg":"./bin/cli.js"}})
    )

    File.write!(Path.join(pkg_dir, "greeting.js"), "export default 'hello-from-import'")
    File.mkdir_p!(Path.join(pkg_dir, "bin"))

    File.write!(
      Path.join(pkg_dir, "bin/cli.js"),
      "#!/usr/bin/env node\nimport greeting from '#greeting';\nconsole.log(greeting)"
    )

    File.ln_s!(Path.join(pkg_dir, "bin/cli.js"), Path.join(bin_dir, "mypkg"))

    {output, status} =
      Runner.run(Path.join(bin_dir, "mypkg"), [],
        node_modules_dir: Path.join(dir, "node_modules"),
        cd: dir
      )

    assert status == 0, output
    assert output =~ "hello-from-import"
  end
end
