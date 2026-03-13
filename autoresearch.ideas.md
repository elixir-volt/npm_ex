# Autoresearch Ideas

## Implemented
- ~~Nested linker, PeerDeps, Dedupe, Workspace, Outdated, Audit, Why, Diff, Fund, License~~
- ~~Prune, Pack, Shrinkwrap, DepCheck, Deprecation, Tree, Search, Stats, Overrides, Verify~~
- ~~Scripts, Token, Publish, Size, BinResolver tests, Compiler tests~~
- ~~Split monolith test file, ex_dna quality gate, fixed code clones~~

## Medium Priority: New Modules
- `NPM.Init` — generate package.json interactively
- `NPM.Link` — local package linking (symlink-based)
- `NPM.CI` — strict frozen install with validation
- `NPM.Doctor` — health check for the npm installation

## Medium Priority: More Tests
- Error handling paths in Registry, Tarball, Cache
- Concurrent access patterns in Cache, NodeModules
- Edge cases in Resolver, Linker
- More tests for existing mix tasks

## Lower Priority: Enhance Existing
- Pre/post install script execution in Hooks
- bundleDependencies handling in Tarball
- devDependencies support in Resolver (--production flag)
