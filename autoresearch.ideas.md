# Autoresearch Ideas

## Completed — 31 tasks, 15 lib modules, 293 tests
- devDependencies, optionalDependencies, overrides, resolutions, workspaces
- bin linking, pruning, --save-exact/--save-dev/--save-optional/--production
- Custom registry, auth tokens, retry, .npmrc, SHA-256, peerDeps (+ meta), deprecation warnings
- Lockfile diff, NPM.Validator, NPM.Compiler, NPM.Config, file:/git: dep detection
- NPM.Exports (conditional exports, ESM/CJS), NPM.Platform (os/cpu/engines), NPM.Lifecycle
- 31 Mix tasks: init install get remove list ls update outdated tree why info search run exec ci check clean cache config version link diff pack audit dedupe prune fund rebuild uninstall doctor

## High-Value Pending Features
- **`mix npm.publish`** — publish to npm registry with token auth (pack + upload tarball)
- **Lockfile v2 format** — add checksums inline, faster verification
- **`bundleDependencies` support** — handle bundled deps in tarballs
- **Progress bar** — show download progress during multi-package fetch
- **Nested node_modules** — create nested dirs when version conflicts exist (proper npm algorithm)
- **NPM.Alias module** — package aliases (`npm:pkg@version` syntax)
- **`mix npm.set`** — set config values in .npmrc
- **`mix npm.token`** — manage auth tokens
- **`mix npm.view`** — view registry info for any package (alias for npm.info with more fields)
- **`install --ignore-scripts`** — explicit flag to skip lifecycle scripts
- **`mix npm.shrinkwrap`** — create npm-shrinkwrap.json for publishing
- **NPM.Semver integration tests** — test actual version constraint matching against known npm behaviors
