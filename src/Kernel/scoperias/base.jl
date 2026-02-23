# ============================================================
# scoperias/base.jl — SimuleosScope constructors
# ============================================================

"""
    SimuleosScope(labels, variables, metadata)

Construct a scope with flexible input types.
- `variables` can be Dict{Symbol, ScopeVariable} or Dict{Symbol, Any}
  (raw values are wrapped as InlineScopeVariable with :local level)
"""
function SimuleosScope(labels::Vector{String}, variables::Dict{Symbol, Any}, metadata::Dict{Symbol, Any})
    typed_vars = Dict{Symbol, ScopeVariable}()
    for (name, val) in variables
        if val isa ScopeVariable
            typed_vars[name] = val
        else
            typed_vars[name] = InlineScopeVariable(:local, type_short(val), val)
        end
    end
    return SimuleosScope(labels, typed_vars, metadata)
end

SimuleosScope(labels::Vector{String}) = SimuleosScope(labels, Dict{Symbol, ScopeVariable}(), Dict{Symbol, Any}())
SimuleosScope(label::String) = SimuleosScope(String[label])

"""
    _make_scope_variable(level, value, inline_vars, blob_vars, hash_vars, name, storage) -> ScopeVariable

Create the appropriate ScopeVariable for a captured value.
Routing priority:
1. Module/Function → Void (never serialized)
2. name ∈ inline_vars → Inline (user forced JSON)
3. name ∈ blob_vars → Blob (user forced binary)
4. name ∈ hash_vars → Hashed (SHA-1 fingerprint only)
5. _is_lite(value) → Inline (scalars are always safe)
6. Otherwise → Void (type recorded, value skipped)
"""
function _make_scope_variable(
        level::Symbol, value,
        inline_vars::Set{Symbol}, blob_vars::Set{Symbol},
        hash_vars::Set{Symbol},
        name::Symbol, storage::Union{BlobStorage, Nothing}
    )
    ts = type_short(value)

    # 1. Void for non-serializable types
    if is_capture_excluded(value)
        return VoidScopeVariable(level, ts)
    end

    # 2. User forced inline
    if name in inline_vars
        return InlineScopeVariable(level, ts, value)
    end

    # 3. Blob storage for marked variables
    if name in blob_vars && !isnothing(storage)
        key = (string(name), hash(value))
        ref = blob_write(storage, key, value; overwrite=true)
        return BlobScopeVariable(level, ts, ref)
    end

    # 4. Hash-only storage for marked variables
    if name in hash_vars
        vh = blob_ref(("value_hash_v1", string(name), value)).hash
        return HashedScopeVariable(level, ts, vh)
    end

    # 5. Lite scalars inline automatically
    if _is_lite(value)
        return InlineScopeVariable(level, ts, value)
    end

    # 6. Default: Void (type recorded, value skipped)
    return VoidScopeVariable(level, ts)
end

# Backward-compatible 6-arg form (no hash_vars)
function _make_scope_variable(
        level::Symbol, value,
        inline_vars::Set{Symbol}, blob_vars::Set{Symbol},
        name::Symbol, storage::Union{BlobStorage, Nothing}
    )
    _make_scope_variable(level, value, inline_vars, blob_vars, Set{Symbol}(), name, storage)
end
