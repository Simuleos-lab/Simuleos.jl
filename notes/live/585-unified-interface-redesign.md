# Unified Interface Redesign

Status: design discussion (2026-03-06)

## Core Principle

**`@simos` = system boundary (query, record, configure, hydrate). Functions = object boundary (extract, inspect, transform).**

The analogy is system calls vs object manipulation. `@simos` is how you talk to the Simuleos OS. Once data crosses into your Julia process, it's a plain object.

Macros may also be used for non-system reasons (e.g. `bind` needs compile-time scope injection).

## Decisions

### 1. All disk/system operations go through `@simos`

Reading, writing, querying, hydrating — anything that touches tape, blob storage, SQLite, or sessions.

### 2. Functional interface is for object manipulation only

Working with objects already in hand: inspecting fields, extracting metadata, type checks. No disk access.

### 3. `@simos query` — unified querying

```julia
@simos query(;
    class = "rec.capture_commit",
    session = "uh1.fix.point.fba.v1",
    latest = true,
    where = "[?scopes[*].labels[0] == 'main.sample']",
)
```

- **Built-in kwargs** (`class`, `session`, `latest`, `limit`) — fast pre-filters, can be index-accelerated
- **`where`** — JMESPath expression string for general post-filtering on JSON-compatible data
- Built-in kwargs narrow first (cheap), then `where` filters candidates (expressive)

### 4. `@simos hydrate` — resolve BlobRefs into values

```julia
# Simple: container has variables directly (e.g. snap.scope)
data = @simos hydrate(scope, :df)
# data is a NamedTuple: (df = <DataFrame>,)

# Nested: use JMESPath to navigate to the BlobRef targets
data = @simos hydrate(commit, "scopes[0].variables", :df)
data = @simos hydrate(commit, "scopes[?labels[0] == 'main.sample'].variables", :df)
```

- System call because it hits blob storage to resolve BlobRefs
- Container can be any SimuleosDataClass — not scope-specific
- JMESPath path argument navigates inside the container to locate BlobRef objects
- Path is optional — omitted when the container directly holds the targets (e.g. `snap.scope`)
- Returns a NamedTuple

### 5. `@simos bind` — hydrate variables + inject into Julia scope

```julia
# Simple: container has variables directly
@simos bind(scope, x, y)
# x, y are now local variables with hydrated values

# Nested: JMESPath navigates to the variable objects
@simos bind(commit, "scopes[0].variables", x, y)
@simos bind(commit, "scopes[?labels[0] == 'main.sample'].variables", x, y)
```

- Needs macro for scope injection
- Container can be any SimuleosDataClass that contains variable objects
- JMESPath path argument navigates inside the container to locate variable objects
- Path is optional — omitted when the container directly holds variables
- Generalizes the old `scope.bind`

### 6. JMESPath module inside Kernel

JMESPath serves dual purpose across the interface:
1. **In `query` `where`** — filtering which records to return from the system
2. **In `bind`/`hydrate`** — navigating inside a container to locate target objects (variables, BlobRefs)

Same language, two uses. Consistent.

Minimal subset:

**Must have:**
- Field access: `metadata.git_commit`
- Array index: `scopes[0]`
- Flatten: `scopes[*].labels`
- Filter expressions: `[?commit_label == 'main.sample']`
- Comparison operators: `==`, `!=`, `<`, `>`, `<=`, `>=`
- Logical: `&&`, `||`, `!`

**Deferred:**
- Multi-select lists/hashes
- Functions (`length()`, `sort()`, `contains()`, etc.)
- Pipe expressions
- Slice syntax

## What this replaces

| Old (functional export) | New (`@simos` system call) |
|---|---|
| `latest_scope(proj; session=..., commit_label=...)` | `@simos query(; class="snap.scope", session=..., latest=true, where="[?commit_label == '...']")` |
| `each_scopes(proj; session=...)` | `@simos query(; class="snap.scope", session=...)` |
| `each_commits(proj; ...)` | `@simos query(; class="rec.capture_commit", ...)` |
| `scope_table(proj; ...)` | TBD — may stay functional as a format transform on query results |
| `value(scope.variables[:x], proj)` | `@simos hydrate(scope, :x)` or `@simos hydrate(commit, "scopes[0].variables", :x)` |
| `@simos scope.bind(scope, proj, x, y)` | `@simos bind(scope, x, y)` or `@simos bind(commit, "scopes[0].variables", x, y)` |

Old exported functions: **delete**, no deprecation.

## Open questions

- `scope_table` — is it a system call or a functional transform on already-queried data?
- `bind` / `hydrate` namespace — do they live under a namespace (`@simos scope.bind`) or top-level (`@simos bind`)?
- Should `where` support multiple expressions (vector of strings) or always one string?
- `proj` parameter — currently threaded everywhere. With `@simos` the system knows the active project. Do we drop explicit `proj` from the query interface?
- JMESPath path in `bind`/`hydrate` — when omitted, how does the system resolve the default? By data class convention (e.g. `snap.scope` → `.variables`)?
- When JMESPath navigation in `bind`/`hydrate` matches multiple targets (e.g. `scopes[*].variables`), what is the merge/conflict behavior for overlapping variable names?

---

## Implementation TODO

### Phase 0: Resolve open questions
- [ ] Decide `bind`/`hydrate` namespace (top-level vs under a group)
- [ ] Decide `proj` parameter: implicit from active project or explicit
- [ ] Decide default path resolution when JMESPath omitted in `bind`/`hydrate`
- [ ] Decide multi-match behavior for `bind`/`hydrate` with wildcard paths
- [ ] Decide `scope_table` fate (system call vs functional transform)
- [ ] Decide `where` shape (single string vs vector of strings)

### Phase 1: JMESPath module (`Kernel/Infra/jmespath/`) ✅ DONE

Implemented 2026-03-06. All 73 tests pass, full suite green.

**Files:**
- `Kernel/Infra/jmespath/types.jl` — 14 AST node types
- `Kernel/Infra/jmespath/tokenizer.jl` — 23 token types
- `Kernel/Infra/jmespath/parser.jl` — recursive descent, correct precedence
- `Kernel/Infra/jmespath/eval.jl` — evaluator over Dict/Vector with JMESPath semantics
- `Kernel/Infra/jmespath/jmespath.jl` — module entry point
- `test/jmespath_tests.jl` — 73 tests, 15 test sets

**Internal API:** `Kernel.jmespath_search(expression, data)`

**Supported subset:** field access, array index, `*`, `[*]`, `[]`, `[?predicate]`, `== != < <= > >=`, `&& || !`, backtick literals, raw strings, quoted identifiers, projection chaining.

### Phase 2: `@simos query` command
- [ ] Define `(:query,)` command spec in dispatch table
- [ ] Handler: accept built-in kwargs (`class`, `session`, `latest`, `limit`)
- [ ] Handler: accept `where` kwarg, parse as JMESPath, apply as post-filter
- [ ] Wire to tape reader: scan session tapes, decode records, filter
- [ ] Wire to SQLite index: use built-in kwargs as SQL pre-filter when index available
- [ ] Return type: vector of decoded SimuleosDataClass objects
- [ ] Tests: query by class, session, label, latest, where expression

### Phase 3: `@simos hydrate` command
- [ ] Define `(:hydrate,)` command spec in dispatch table
- [ ] Handler: accept container + optional JMESPath path + symbol names
- [ ] Navigate container using JMESPath path to locate BlobRef objects
- [ ] Resolve BlobRefs via blob storage
- [ ] Return NamedTuple of hydrated values
- [ ] Tests: hydrate from snap.scope (no path), from rec.capture_commit (with path)

### Phase 4: `@simos bind` command
- [ ] Define `(:bind,)` command spec in dispatch table
- [ ] Handler (macro): accept container + optional JMESPath path + bare variable names
- [ ] Navigate container using JMESPath path to locate variable objects
- [ ] Hydrate variable values (resolve BlobRefs as needed)
- [ ] Inject into caller's scope
- [ ] Tests: bind from snap.scope (no path), from rec.capture_commit (with path)

### Phase 5: Delete old functional interface
- [ ] Remove exports: `latest_scope`, `each_scopes`, `each_commits`, `scope_table`, `value`, `project`
- [ ] Delete implementation files for old reader functions
- [ ] Remove old `(:scope, :bind)` command from dispatch table
- [ ] Update `Simuleos.jl` exports list
- [ ] Update all examples in `examples/workflows/` to use new interface
- [ ] Update `simuleos-usage` skill (SKILL.md)

### Phase 6: Validate
- [ ] Run full test suite
- [ ] Run `Auxotrophs_CoCultures_20251109` scripts end-to-end with new interface
- [ ] Verify tape records are identical (recording path unchanged)
