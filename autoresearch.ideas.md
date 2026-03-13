# Autoresearch Ideas

## High Priority: Nested Linker (express fully works end-to-end)
- Two-phase resolver already works: detects conflicts, excludes package, retries with nesting
- `Resolver.get_original_deps/1` tracks which parents need which version of excluded pkg
- Need: Linker creates `parent_pkg/node_modules/excluded_pkg/` directories
- Need: Lockfile tracks nested entries (version, integrity, parents)
- This makes `mix npm.install express` actually produce working node_modules

## Medium Priority: Real Features
- `npm ci --frozen-lockfile` strict mode (reject if lockfile is out of sync)
- `npm ls --json` output for tooling integration
- `npm why` trace through nested deps
- Pre/post install script execution (currently only detection)
- `npm pack` integration with tarball creation from local project
- Progress bar / streaming output during multi-package downloads

## Lower Priority: Polish
- `npm audit` with real advisory API integration
- `npm diff` between installed and registry versions
- `npm fund` with real funding URL display
- bundleDependencies handling in tarballs
