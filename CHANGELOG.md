# Changelog

## 0.4.4

- Fix npm registry packument decoding for optional platform dependency inspection
- Select the correct platform-specific optional binding for packages like `oxfmt` and `oxlint`
- Keep `mix npm.exec` running binaries through Node instead of shell string spawning
- Preserve `optional_dependencies` in `npm.lock`
- Skip linking crashes when optional packages are unavailable

## 0.4.3

- Fix `mix npm.exec` to resolve binaries via `NPM.Exec.which/2` and run them through Node instead of shell string spawning
- Preserve `optional_dependencies` in `npm.lock`
- Skip linking missing optional packages instead of crashing during install
- Add focused test coverage for exec environment, cached Node runner execution, optional runtime linking, and resolver optional dependency handling

## 0.4.2

- Speculative parallel prefetch of transitive dependencies before solving — fetches the full dep tree breadth-first with 16 concurrent requests
- Deduplicate `format_size`/`format_bytes` across 8 modules into `NPM.Format.bytes/1`

## 0.4.1

- Fix mix tasks crashing with `unknown registry: Req.Finch` when host app hasn't started the HTTP stack

## 0.4.0

### New Mix Tasks (21 new, 43 total)

- `mix npm.init` — create a new `package.json`
- `mix npm.update` — update all or specific packages
- `mix npm.outdated` — show packages with newer versions available
- `mix npm.tree` — display full dependency tree
- `mix npm.why` / `mix npm.explain` — explain why a package is installed
- `mix npm.info` / `mix npm.view` — show package details from the registry
- `mix npm.search` — search the npm registry
- `mix npm.run` — run scripts from `package.json`
- `mix npm.exec` — execute binaries from `node_modules/.bin/`
- `mix npm.ci` — frozen lockfile install (CI shortcut)
- `mix npm.check` / `mix npm.verify` — verify installation state
- `mix npm.clean` — remove `node_modules/`
- `mix npm.cache` — manage global cache
- `mix npm.config` / `mix npm.set` — show and modify configuration
- `mix npm.version` — show npm_ex version
- `mix npm.link` — link local packages for development
- `mix npm.diff` — show lockfile changes since last commit
- `mix npm.pack` — create a tarball of the current package
- `mix npm.audit` — check for security vulnerabilities
- `mix npm.dedupe` — re-resolve to minimize duplicates
- `mix npm.prune` — remove extraneous packages
- `mix npm.fund` — show package funding info
- `mix npm.rebuild` — clean and reinstall from lockfile
- `mix npm.uninstall` — alias for `npm.remove`
- `mix npm.deps` — list installed packages (`mix deps`-style output)
- `mix npm.deprecations` — show deprecated packages
- `mix npm.doctor` — diagnose common setup problems
- `mix npm.licenses` — list dependency licenses
- `mix npm.ls` — alias for `mix npm.list`
- `mix npm.publish` — publish package to registry
- `mix npm.shrinkwrap` — generate npm-shrinkwrap.json
- `mix npm.size` — estimate installed package sizes
- `mix npm.stats` — show dependency statistics
- `mix npm.token` — manage registry auth tokens
- `mix npm.completion` — shell completion helpers

### Install UX

- `mix deps`-style output after install — packages listed as `* name version (npm registry)`
- Progress reporting for resolution, fetching, and linking steps
- Structured error messages with actionable suggestions
- Lockfile diff output showing added/removed/updated packages on install
- Project setup checklist (`NPM.ProjectInit`)

### Dependency Analysis (30+ modules)

- `NPM.DepGraph` — adjacency list, fan-in/out, cycle detection, orphans
- `NPM.GraphOps` — transitive closure, shortest path, impact scoring
- `NPM.DepSort` — topological sorting, parallel install levels
- `NPM.DepRange` — classify ranges (exact, caret, tilde, star, file, git, url)
- `NPM.DepConflict` — detect version conflicts between dependency groups
- `NPM.DepFreshness` — classify package freshness (current, outdated, ancient)
- `NPM.DepStats` — aggregate statistics (scope distribution, version breakdown)
- `NPM.DepPath` — resolve bin and module paths within node_modules
- `NPM.DepCheck` — verify installed tree matches lockfile
- `NPM.PhantomDep` — detect undeclared (phantom) dependencies
- `NPM.HoistingConflict` — detect version conflicts from hoisting
- `NPM.PeerDep` / `NPM.PeerDepsCheck` — peer dependency validation
- `NPM.PackageUpdate` — compute available major/minor/patch updates
- `NPM.OutdatedReport` — npm outdated-style table formatting
- `NPM.SnapshotDiff` — lockfile snapshot comparison
- `NPM.ManifestDiff` — diff two package.json files
- `NPM.IntegrityCheck` — verify installed packages match lockfile
- `NPM.LockfileCheck` / `NPM.LockfileStats` — lockfile validation and metrics

### Package Metadata (20+ modules)

- `NPM.Validate` — package.json schema validation
- `NPM.Engines` / `NPM.NodeVersion` — engine constraints and .nvmrc/.tool-versions parsing
- `NPM.Compat` — Node.js version compatibility checking
- `NPM.Funding` — funding field parsing
- `NPM.TypeField` — module type detection (ESM/CJS)
- `NPM.SideEffects` — tree-shaking side-effects field
- `NPM.Conditional` — conditional exports/imports resolution
- `NPM.Exports` / `NPM.TypesResolution` — package exports and types resolution
- `NPM.PublishConfig` — publish configuration
- `NPM.Corepack` — packageManager field parsing
- `NPM.PackageQuality` — metadata quality scoring
- `NPM.PackageFiles` — files field and .npmignore analysis
- `NPM.BundleAnalysis` — bundle-friendliness scoring
- `NPM.ImportMap` — browser import map generation
- `NPM.TypesCompanion` — suggest @types/* companion packages
- `NPM.ScriptRunner` — script analysis and pattern detection
- `NPM.ReleaseNotes` — changelog version extraction

### Security & Supply Chain

- `NPM.CVE` — CVE detection and scoring
- `NPM.SBOM` — software bill of materials generation
- `NPM.SupplyChain` — supply chain risk assessment
- `NPM.Provenance` — package provenance verification
- `NPM.DeprecationAnalysis` — deprecation severity analysis

### Configuration

- `NPM.Npmrc` — .npmrc file parsing
- `NPM.NpmrcMerge` — multi-layer .npmrc resolution (project → user → global)
- `NPM.RegistryUrl` — registry URL resolution with scope support
- `NPM.InstallStrategy` — hoisted/nested/isolated install strategies
- `NPM.Workspaces` — workspace configuration and glob matching
- `NPM.Migration` — npm version migration guidance

### Infrastructure

- `NPM.Compiler` — Mix compiler for automatic npm installs
- `NPM.CacheStats` — cache hit/miss metrics and disk usage
- `NPM.ProgressReporter` — structured progress output
- `NPM.ErrorMessage` — error formatting with suggestions
- `NPM.DepsOutput` — `mix deps`-style package listing
- `NPM.Diagnostics` — project health diagnostics
- `NPM.Gitignore` — .gitignore management for npm projects

### Other

- `devDependencies` support (`--save-dev`, `--production`)
- `optionalDependencies` support (`--save-optional`)
- `--save-exact` flag for pinning exact versions
- `node_modules/.bin/` executable linking
- `overrides` support in `package.json`
- Custom registry URL via `NPM_REGISTRY` env var
- Auth token support via `NPM_TOKEN` env var
- SHA-256 integrity verification (in addition to SHA-512 and SHA-1)
- Retry with exponential backoff for failed HTTP requests
- `file:` dependency references
- 2,697 tests (up from 64)

## 0.3.1

- Rename repository to [npm_ex](https://github.com/dannote/npm_ex)

## 0.3.0

- `mix npm.remove` — remove a package from `package.json`
- `mix npm.list` — show installed packages with versions
- `mix npm.install --frozen` — fail if lockfile is stale (CI mode)
- Fix scoped package parsing (`@scope/pkg@^1.0` was splitting incorrectly)
- Timing output for resolve and install steps
- Rename `install/2` to `add/2` in the public API
- Expand test suite to 64 tests

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
