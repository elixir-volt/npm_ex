# Changelog

## 0.2.0

- Global package cache at `~/.npm_ex/cache/` — download once, reuse across projects
- `node_modules/` linking via symlinks (unix) or copies (Windows)
- Hoisted flat layout
- Switch from `:httpc` to Req for HTTP
- Add `mix npm.get` task
- Add credo, ex_slop, ex_dna, dialyzer
- Add unit and integration tests
- Add GitHub Actions CI

## 0.1.0

Initial release.

- `mix npm.install` — resolve and install all deps from `package.json`
- `mix npm.install <pkg>` — add a package and install
- PubGrub dependency resolution via `hex_solver`
- npm registry client with abbreviated packuments
- SHA-512 integrity verification
- `npm.lock` lockfile for reproducible installs
