# Recording vs Query System Integration - Decisions

**Issue**: Should the recording system and query system share types or remain independent?

---

## Context

Two systems exist:

| System | Purpose | Types | API Style |
|--------|---------|-------|-----------|
| Recording | Capture simulation state | `Scope`, `ScopeVariable` (mutable) | Field access: `scope.label` |
| Query | Load recorded data | `ScopeWrapper`, `VariableWrapper` (immutable) | Functions: `label(scope)` |

JSON format on disk acts as contract between them.

---

## Questions & Decisions

**Q**: Does generic code matter — functions that work with both recording and query types?

**A**: Yes, this is desirable. Want to write utilities that don't care about source.

---

**Q**: API consistency preference?

**A**: Both should use accessor functions: `label(x)`, `src_type(v)`, etc.

---

**Q**: Naming: `*Wrapper` vs `*View`?

**A**: Rename to `*View` — clearer semantics (read-only window into data).

---

**Q**: Data flow direction — does data flow back from query to recording?

**A**: Yes, eventually. Load disk → old session → julia scope → modify → re-commit. System is append-only — committing adds new records, doesn't modify old ones on disk.

---

**Q**: Schema evolution concern?

**A**: Not a priority now. Raw readers (`iterate_raw_tape`, `load_raw_blob`) provide escape hatch if format changes.

---

**Q**: Where do abstractions live — abstract types or duck typing?

**A**: **Duck typing only** (Option Z). No `AbstractScope` hierarchy. Just matching function signatures. Both `Scope` and `ScopeView` implement `label()`, `variables()`, etc.

---

**Q**: Immediate action?

**A**: **Document only** — no code changes yet.

---

## Decision Summary

```
┌─────────────────────────────────────────────────────────────┐
│  RECORDING                    QUERY                         │
│  (mutable)                    (immutable)                   │
├─────────────────────────────────────────────────────────────┤
│  Scope                        ScopeView                     │
│    label(s)                     label(s)                    │
│    timestamp(s)                 timestamp(s)                │
│    variables(s)                 variables(s)                │
│    labels(s)                    labels(s)                   │
│    data(s)                      data(s)                     │
│                                                             │
│  ScopeVariable                VariableView                  │
│    name(v)                      name(v)                     │
│    src_type(v)                  src_type(v)                 │
│    value(v)                     value(v)                    │
│    blob_ref(v)                  blob_ref(v)                 │
│    src(v)                       src(v)                      │
├─────────────────────────────────────────────────────────────┤
│  Duck typing: generic code uses accessor functions          │
│  No abstract types needed                                   │
│  JSON on disk = stable contract                             │
│  Raw readers = escape hatch for schema changes              │
└─────────────────────────────────────────────────────────────┘
```

## Future Work (when needed)

1. Add accessor functions to recording types (`src/types.jl`)
2. Rename `*Wrapper` → `*View` in query module
3. Export unified API from `Simuleos.jl`
4. Support load → append workflow (new commits reference old data)
