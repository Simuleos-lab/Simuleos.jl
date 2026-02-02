# Git Interface Design - Decisions

**Topic**: Build a common interface for Simuleos to interact with git using LibGit2.jl instead of direct shell commands

---

## Core Design Principles

**Q**: What is the scope and philosophy?
**A**: Start minimal with essential operations, grow organically over time, eventually expose to users for their own code (not just internal Simuleos use).

**Q**: What API style should we use?
**A**: Functional (Julia idiomatic) with a `GitHandler` struct. Methods operate on the struct.

**Q**: How should errors be handled?
**A**: Throw exceptions - callers must handle them. Re-throw LibGit2 errors as-is without custom wrappers.

**Q**: Where should this code live?
**A**: `src/git.jl` as a new module

---

## GitHandler Design

**Q**: What should the GitHandler struct contain?
**A**: Just store the path. Open LibGit2 repo on each operation (no persistent handle to manage).

**Q**: What should the constructor do?
**A**: Lazy validation - just store the path, validate on first operation.

**Q**: How do we verify repo identity for safety?
**A**: Store `.git` directory path at construction. On each operation, use LibGit2 to get the repo root and compare it with the stored path. This prevents touching unintended repos.

**Q**: What about initialization?
**A**: Provide `init(gh::GitHandler)` function that operates on a handler. This is the exception to the "don't touch unintended repos" rule.

---

## Operations

**Q**: What operations should the first version implement?
**A**: Common read operations:
- `hash(gh)` - Get current commit hash
- `dirty(gh)` - Check if repo has uncommitted changes
- `describe(gh)` - Get git describe output
- `branch(gh)` - Get current branch name
- `remote(gh)` - Get remote URL

**Q**: What naming convention for methods?
**A**: Concise names (Julia style): `hash()`, `dirty()`, `describe()`, `branch()`, `remote()`

---

## Module Organization

**Q**: What should be exported?
**A**: Nothing. Users should use qualified names like `Simuleos.Git.GitHandler`.

**Q**: How should we migrate existing code?
**A**: Update `src/metadata.jl` immediately to use the new `GitHandler` interface.

---

## Testing

**Q**: What level of testing?
**A**: Basic testing - verify each method works correctly in a simple git repository.

---

## Decision Summary

Create `src/git.jl` with:
- `GitHandler` struct storing repo path
- Lazy validation with strict repo identity verification
- Concise functional methods: `hash()`, `dirty()`, `describe()`, `branch()`, `remote()`
- `init()` function for repo initialization
- No custom error types - re-throw LibGit2 errors
- No exports - use qualified names
- Immediately migrate `metadata.jl` to use new interface
- Basic test coverage
