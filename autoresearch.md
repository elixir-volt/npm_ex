# Autoresearch: npm_ex Feature Development

## Goal
Add features to npm_ex, an npm package manager for Elixir (no Node.js required).

## Primary Metric
- **test_count** — total passing tests (higher is better)
- Every new feature must come with comprehensive tests

## Quality Gate (autoresearch.checks.sh)
- `mix test` must pass (exit 0)
- `mix format --check-formatted` must pass
- `mix credo --strict` must pass
- No regressions — existing 64 tests must continue to pass

## Feature Backlog (priority order)

1. **`devDependencies` support** — read `devDependencies` from `package.json`, install by default, skip with `--production` flag
2. **Stale package pruning** — remove packages from `node_modules/` that are no longer in the lockfile
3. **`mix npm.outdated`** — show packages with newer versions available on the registry
4. **`bin` linking** — create `node_modules/.bin/` with executables from package `bin` field
5. **`mix npm.update`** — update one or all packages to latest matching versions
6. **`peerDependencies` warnings** — warn about unmet peer dependencies during resolution
7. **Lockfile integrity check** — verify lockfile entries match package.json deps

## Rules
- One feature per experiment iteration
- Each feature needs both unit tests and (where applicable) integration tests
- Follow existing code style and patterns
- Keep modules focused and small
- Test helpers go in the test files, not in lib/

## Benchmark Command
```sh
MIX_ENV=test mix test 2>&1 | tail -5
```

## How to Extract Metric
Parse the ExUnit output line: `N tests, 0 failures`
The primary metric is N (test count).
