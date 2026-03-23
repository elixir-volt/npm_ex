defmodule NPM.NodeRunner do
  @moduledoc false

  @spec run(String.t(), [String.t()], keyword()) :: {String.t(), non_neg_integer()}
  def run(entrypoint, args, opts \\ []) do
    node_modules_dir = Keyword.get(opts, :node_modules_dir, "node_modules")
    env = Keyword.get(opts, :env, []) ++ NPM.Exec.env(node_modules_dir)

    loader_path = write_loader(Path.expand(node_modules_dir), Path.expand(entrypoint))

    try do
      System.cmd("node", [loader_path | args],
        env: env,
        stderr_to_stdout: true,
        cd: Keyword.get(opts, :cd, File.cwd!())
      )
    after
      File.rm(loader_path)
    end
  end

  defp write_loader(node_modules_dir, entrypoint) do
    path = Path.join(System.tmp_dir!(), "npm-node-runner-#{System.unique_integer([:positive])}.mjs")

    File.write!(path, """
    import { createRequire } from 'node:module'
    const require = createRequire(import.meta.url)
    globalThis.require = require
    process.env.NODE_PATH = #{inspect(node_modules_dir)}
    require('node:module').Module._initPaths()
    await import(#{inspect(entrypoint)})
    """)

    path
  end
end
