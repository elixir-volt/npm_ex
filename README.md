# NPM

[![Hex.pm](https://img.shields.io/hexpm/v/npm.svg)](https://hex.pm/packages/npm)
[![CI](https://github.com/elixir-volt/npm_ex/actions/workflows/ci.yml/badge.svg)](https://github.com/elixir-volt/npm_ex/actions/workflows/ci.yml)

npm package manager for Elixir — no Node.js required.

Resolve, fetch, cache, and link npm packages directly from Mix.

## Installation

```elixir
def deps do
  [{:npm, "~> 0.6.1"}]
end
```

## Usage

```sh
# Initialize a new package.json
mix npm.init

# Install all deps from package.json
mix npm.install

# Add a package (latest)
mix npm.install lodash

# Add with version range
mix npm.install lodash@^4.0

# Scoped packages
mix npm.install @types/node@^20

# Add as dev dependency
mix npm.install eslint --save-dev

# Pin exact version (no ^ prefix)
mix npm.install lodash --save-exact

# Production install (skip devDependencies)
mix npm.install --production

# Remove a package
mix npm.remove lodash

# Update packages
mix npm.update            # Update all
mix npm.update lodash     # Update specific

# List installed packages
mix npm.list

# Show dependency tree
mix npm.tree

# Show outdated packages
mix npm.outdated

# Explain why a package is installed
mix npm.why accepts

# Show package info from the registry
mix npm.info express

# Search the registry
mix npm.search react

# Run a script from package.json
mix npm.run build

# Execute a binary from node_modules/.bin
mix npm.exec eslint .

# Fetch locked deps without re-resolving
mix npm.get

# CI mode — fail if lockfile is stale
mix npm.install --frozen
mix npm.ci

# Verify installation state
mix npm.check

# Clean node_modules
mix npm.clean

# Cache management
mix npm.cache status
mix npm.cache clean

# Show configuration
mix npm.config
```

## How it works

1. Reads dependencies from `package.json` (supports `dependencies`, `devDependencies`, `overrides`)
2. Resolves the full dependency tree using [PubGrub](https://hex.pm/packages/hex_solver) with [npm semver](https://hex.pm/packages/npm_semver)
3. Downloads tarballs from the npm registry with SHA-512/SHA-256/SHA-1 integrity verification
4. Caches packages globally in `~/.npm_ex/cache/` — download once, reuse across projects
5. Links into `node_modules/` via symlinks (macOS/Linux) or copies (Windows)
6. Creates `node_modules/.bin/` with executable symlinks from package `bin` fields
7. Prunes stale packages from `node_modules/` on re-install
8. Locks versions in `npm.lock` for reproducible installs
9. Warns about unmet peer dependencies and deprecated packages
10. Retries failed downloads with exponential backoff

## Supply-chain safety

`npm_ex` does not run package lifecycle hooks automatically. Packages with `preinstall`, `install`, `postinstall`, or `prepare` scripts are still installed, but their hooks are ignored and reported as warnings. Tarball paths are also validated before extraction so package contents cannot escape the cache directory.

This blocks install-time credential stealers that rely on postinstall hooks reading files like `.env` and exfiltrating them during dependency installation.

## Why `npm.lock` instead of `package-lock.json`?

`npm_ex` is not npm, so it keeps its own lockfile. `package.json` is the shared manifest; `npm.lock` is the reproducibility file for the `npm_ex` installer.

## Module organization

The main public API is `NPM`. Supporting APIs are grouped by domain:

- `NPM.Package.*` — package.json, manifests, package metadata, repository, license, funding, and quality helpers
- `NPM.Dependency.*` — dependency graphs, ranges, conflicts, peers, outdated checks, dedupe, and usage checks
- `NPM.Lockfile.*` — lockfile validation, stats, merge, package-lock, and shrinkwrap helpers
- `NPM.Security.*` — audit, CVE, provenance, supply-chain, and exotic dependency policy helpers
- `NPM.Diagnostics.*` — project diagnostics, doctor, environment, engine, and health checks
- `NPM.Registry.*` — registry URLs, mirrors, scoped registries, and tokens
- `NPM.Config.*` — `.npmrc` parsing and multi-layer config resolution
- `NPM.Install.*` — linking, pruning, rebuilding, lifecycle/script metadata, CI, and runtime install helpers
- `NPM.Node.*` — Node execution and binary resolution helpers
- `NPM.NodeModules.*` — node_modules path helpers

## Configuration

Set environment variables to customize behavior:

- `NPM_REGISTRY` — custom registry URL (default: `https://registry.npmjs.org`)
- `NPM_TOKEN` — authentication token for private registries
- `NPM_MIRROR` — registry mirror URL
- `NPM_INSTALL_DIR` — custom `NPM.install/2` runtime install directory
- `NPM_EX_CACHE_DIR` — custom cache directory (default: `~/.npm_ex/`)
- `NPM_EX_BLOCK_EXOTIC_SUBDEPS` — block transitive git, file, and URL dependencies (default: `true`)
- `NPM_EX_EXOTIC_DEPS` — comma-separated allowlist for direct exotic dependency specs (default: empty)
- `NPM_EX_ALLOWED_REGISTRIES` — comma-separated registry origins allowed for packuments and tarballs (default: registry + mirror)
- `NPM_EX_ALLOW_REGISTRY_REDIRECTS` — allow registry HTTP redirects (default: `false`)
- `NPM_EX_PACKAGE_AGE_WARNING_DAYS` — warn for packages created more recently than this many days (default: `7`)
- `NPM_EX_VERSION_AGE_WARNING_DAYS` — warn for versions published more recently than this many days (default: `3`)

Elixir application config is also supported:

```elixir
config :npm,
  registry: "https://registry.npmjs.org",
  token: System.get_env("NPM_TOKEN"),
  mirror: "https://registry.npmmirror.com",
  cache_dir: "/path/to/.npm_ex",
  install_dir: "/path/to/npm-installs",
  block_exotic_subdeps: true,
  exotic_deps: [],
  allowed_registries: ["https://registry.npmjs.org"],
  allow_registry_redirects: false,
  package_age_warning_days: 7,
  version_age_warning_days: 3
```

## License

MIT © 2026 Danila Poyarkov
