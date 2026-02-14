# ScopeTapes record constructors from raw Dict data (all I0x)
# Constructs typed record objects from raw data.

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

function _raw_to_variable_record(name::String, raw::Dict{String, Any})::VariableRecord
    VariableRecord(
        name,
        get(raw, "src_type", ""),
        get(raw, "value", nothing),
        get(raw, "blob_ref", nothing),
        Symbol(get(raw, "src", "local"))
    )
end

function _raw_to_scope_record(raw::Dict{String, Any})::ScopeRecord
    raw_vars = _as_string_any_dict(get(raw, "variables", Dict{String, Any}()))
    vars = [
        _raw_to_variable_record(name, _as_string_any_dict(v))
        for (name, v) in raw_vars
    ]

    ts_str = get(raw, "timestamp", nothing)
    ts = isnothing(ts_str) ? Dates.DateTime(0) : Dates.DateTime(ts_str)

    raw_labels = get(raw, "labels", Any[])
    lbls = String[string(l) for l in raw_labels]

    raw_data = _as_string_any_dict(get(raw, "data", Dict{String, Any}()))

    ScopeRecord(
        get(raw, "label", ""),
        ts,
        vars,
        lbls,
        raw_data
    )
end

function _raw_to_commit_record(raw::Dict{String, Any})::CommitRecord
    raw_scopes = get(raw, "scopes", Any[])
    scope_records = [
        _raw_to_scope_record(_as_string_any_dict(s))
        for s in raw_scopes
    ]

    raw_refs = get(raw, "blob_refs", Any[])
    refs = String[string(r) for r in raw_refs]

    CommitRecord(
        get(raw, "commit_label", ""),
        _as_string_any_dict(get(raw, "metadata", Dict{String, Any}())),
        scope_records,
        refs
    )
end
