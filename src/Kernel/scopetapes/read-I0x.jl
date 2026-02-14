# ScopeTapes constructors from raw Dict data (all I0x)
# Constructs `ScopeCommit` / `Scope` / `ScopeVariable` objects from raw data.

function _as_string_any_dict(raw)::Dict{String, Any}
    raw isa Dict{String, Any} && return raw
    if raw isa AbstractDict
        out = Dict{String, Any}()
        for (k, v) in raw
            out[string(k)] = v
        end
        return out
    end
    return Dict{String, Any}()
end

function _as_symbol_any_dict(raw)::Dict{Symbol, Any}
    if raw isa AbstractDict
        out = Dict{Symbol, Any}()
        for (k, v) in raw
            out[Symbol(string(k))] = v
        end
        return out
    end
    return Dict{Symbol, Any}()
end

function _raw_to_scope_variable(raw::Dict{String, Any})::ScopeVariable
    src = Symbol(get(raw, "src", "local"))
    type_short = get(raw, "src_type", "")

    if haskey(raw, "blob_ref")
        return BlobScopeVariable(src, type_short, BlobRef(string(raw["blob_ref"])))
    end
    if haskey(raw, "value")
        return InMemoryScopeVariable(src, type_short, get(raw, "value", nothing))
    end
    return VoidScopeVariable(src, type_short)
end

function _raw_to_scope(raw::Dict{String, Any})::Scope
    raw_vars = _as_string_any_dict(get(raw, "variables", Dict{String, Any}()))
    vars = Dict{Symbol, ScopeVariable}()
    for (name, raw_var) in raw_vars
        vars[Symbol(name)] = _raw_to_scope_variable(_as_string_any_dict(raw_var))
    end

    primary_label = string(get(raw, "label", ""))
    raw_labels = get(raw, "labels", Any[])
    labels = String[string(l) for l in raw_labels]
    if !isempty(primary_label)
        labels = vcat([primary_label], labels)
    end

    data = _as_symbol_any_dict(get(raw, "data", Dict{String, Any}()))

    Scope(
        labels,
        vars,
        data
    )
end

function _raw_to_scope_commit(raw::Dict{String, Any})::ScopeCommit
    raw_scopes = get(raw, "scopes", Any[])
    scopes = Scope[
        _raw_to_scope(_as_string_any_dict(s))
        for s in raw_scopes
    ]

    ScopeCommit(
        get(raw, "commit_label", ""),
        _as_string_any_dict(get(raw, "metadata", Dict{String, Any}())),
        scopes
    )
end
