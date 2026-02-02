# JSON Serialization - Decisions

**Issue**: Current serialization converts objects to `Dict{String, Any}` before calling `JSON3.write`. This causes unnecessary allocations. Goal is direct JSON serialization from structs for better commit performance.

---

## Decisions

**Q**: JSON3 StructTypes vs custom IO writing?
**A**: Hybrid approach. Use JSON3 for primitives (handles escaping, numbers, strings). Manual serialization for struct layout (`{`, `}`, commas, field names).

**Q**: Field renaming strategy?
**A**: Keep current JSON key names (`type_str`, `labels`, `data`, etc.).

**Q**: Optional fields handling?
**A**: Keep current behavior - omit `nothing` values and empty collections.

**Q**: Function naming convention?
**A**: Single overloaded function `_write_json(io, obj)` with dispatch on type.

**Q**: Signature pattern?
**A**: Returns nothing, pure side-effect.

**Q**: Where does this live?
**A**: New file `src/json.jl`.

**Q**: Dict serialization helper?
**A**: Write `_write_json(io, d::Dict)` for consistent interface. Can use JSON3 internally.

**Q**: Vector/Set handling?
**A**: Same - use `_write_json` interface, can delegate to JSON3 internally.

**Q**: Symbol serialization?
**A**: Convert to string (same as now).

**Q**: DateTime serialization?
**A**: ISO string format.

**Q**: Any type handling?
**A**: Fallback `_write_json(io, x) = JSON3.write(io, x)` as catch-all.

**Q**: Error behavior?
**A**: Let it error (fail fast).

---

## Summary

Create `src/json.jl` with:

```julia
# Fallback - delegates to JSON3
_write_json(io::IO, x) = JSON3.write(io, x)

# Symbol → String
_write_json(io::IO, s::Symbol) = JSON3.write(io, string(s))

# DateTime → ISO string
_write_json(io::IO, dt::DateTime) = JSON3.write(io, string(dt))

# Dict - iterate keys, call _write_json for values
function _write_json(io::IO, d::Dict)
    print(io, "{")
    first = true
    for (k, v) in d
        first || print(io, ",")
        first = false
        _write_json(io, string(k))  # key as string
        print(io, ":")
        _write_json(io, v)
    end
    print(io, "}")
end

# Vector - iterate, call _write_json for elements
function _write_json(io::IO, v::Vector)
    print(io, "[")
    for (i, x) in enumerate(v)
        i > 1 && print(io, ",")
        _write_json(io, x)
    end
    print(io, "]")
end

# ScopeVariable - manual field writing, skip nothing/empty
function _write_json(io::IO, sv::ScopeVariable)
    print(io, "{")
    print(io, "\"type_str\":")
    _write_json(io, sv.type_str)
    print(io, ",\"src\":")
    _write_json(io, sv.src)
    if !isnothing(sv.value)
        print(io, ",\"value\":")
        _write_json(io, sv.value)
    end
    if !isnothing(sv.blob_ref)
        print(io, ",\"blob_ref\":")
        _write_json(io, sv.blob_ref)
    end
    print(io, "}")
end

# Scope - manual field writing, skip empty collections
function _write_json(io::IO, scope::Scope)
    print(io, "{")
    print(io, "\"label\":")
    _write_json(io, scope.label)
    print(io, ",\"timestamp\":")
    _write_json(io, scope.timestamp)
    print(io, ",\"isopen\":")
    _write_json(io, scope.isopen)
    print(io, ",\"variables\":{")
    first = true
    for (name, sv) in scope.variables
        first || print(io, ",")
        first = false
        _write_json(io, name)
        print(io, ":")
        _write_json(io, sv)
    end
    print(io, "}")
    if !isempty(scope.labels)
        print(io, ",\"labels\":")
        _write_json(io, scope.labels)
    end
    if !isempty(scope.data)
        print(io, ",\"data\":")
        _write_json(io, scope.data)
    end
    print(io, "}")
end
```

Update `src/tape.jl`:
- Remove `_scope_variable_to_dict`, `_scope_to_dict`
- Update `_create_commit_record` to write directly using `_write_json`
- Or inline the commit record writing in `_append_to_tape`

Update `src/Simuleos.jl`:
- Add `include("json.jl")` before `include("tape.jl")`

---

## Next Steps

1. Create `src/json.jl` with `_write_json` methods
2. Update `tape.jl` to use `_write_json` instead of dict conversion
3. Run tests to verify output matches
