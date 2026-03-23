# NPM

[![Hex.pm](https://img.shields.io/hexpm/v/npm.svg)](https://hex.pm/packages/npm)
[![CI](https://github.com/elixir-volt/npm_ex/actions/workflows/ci.yml/badge.svg)](https://github.com/elixir-volt/npm_ex/actions/workflows/ci.yml)

npm package manager for Elixir — no Node.js required.

Resolve, fetch, cache, and link npm packages directly from Mix.

## Installation

```elixir
def deps do
  [{:npm, "~> 0.4.0"}]
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

## Why `npm.lock` instead of `package-lock.json`?

`npm_ex` is not npm, so it keeps its own lockfile. `package.json` is the shared manifest; `npm.lock` is the reproducibility file for the `npm_ex` installer.

## Configuration

Set environment variables to customize behavior:

- `NPM_REGISTRY` — custom registry URL (default: `https://registry.npmjs.org`)
- `NPM_TOKEN` — authentication token for private registries
- `NPM_EX_CACHE_DIR` — custom cache directory (default: `~/.npm_ex/`)

## License

MIT © 2026 Danila Poyarkov
