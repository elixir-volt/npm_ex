defmodule NPM.NodeRunnerTest do
  use ExUnit.Case, async: true

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
      NPM.NodeRunner.run(Path.join(cli_dir, "dist/cli.mjs"), [],
        node_modules_dir: Path.join(dir, "node_modules"),
        cd: dir
      )

    assert status == 0, output
    assert output =~ "ok"
  end
end
