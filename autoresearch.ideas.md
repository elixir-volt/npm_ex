# Autoresearch Ideas

## Completed Features (v0.4.0)
- ✅ devDependencies support
- ✅ optionalDependencies support (--save-optional)
- ✅ Stale package pruning
- ✅ bin linking (string/map/directories.bin)
- ✅ --save-exact flag
- ✅ Workspaces support (read/expand)
- ✅ Custom registry URL (NPM_REGISTRY)
- ✅ Auth tokens (NPM_TOKEN)
- ✅ Retry with exponential backoff
- ✅ SHA-256 integrity verification
- ✅ peerDependencies warnings
- ✅ Deprecation warnings
- ✅ Lockfile diff output
- ✅ NPM.Validator (name/range validation)
- ✅ NPM.Compiler (Mix compiler)
- ✅ overrides in package.json

## Completed Tasks (25 total)
- ✅ mix npm.init, install, get, remove, list
- ✅ mix npm.update, outdated, tree, why, info
- ✅ mix npm.search, run, exec, ci, check
- ✅ mix npm.clean, cache, config, version
- ✅ mix npm.link, diff, pack, audit, dedupe

## Pending Ideas
- `.npmrc` file support for registry config
- `mix npm.fund` — show funding info
- `mix npm.publish` — publish to npm registry
- `mix npm.rebuild` — rebuild native packages
- `mix npm.prune` — remove extraneous packages
- Parallel cache downloads with progress bar
- Conditional exports support (package.json "exports" field)
- `type: "module"` detection
- Lock file migration (detect old format)
- `engines` field warnings during install
- Nested node_modules for version conflicts
- Lifecycle scripts (preinstall, postinstall)
- Git dependency support (git+https:// URLs)
- File dependency support (file:../local-pkg)
- `resolutions` field (Yarn-style)
