# ScopeTapes record constructors from raw Dict data (all I0x)
# Constructs typed record objects from raw data.

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
    raw_vars = get(raw, "variables", Dict{String, Any}())
    vars = [_raw_to_variable_record(name, v) for (name, v) in raw_vars]

    ts_str = get(raw, "timestamp", nothing)
    ts = isnothing(ts_str) ? Dates.DateTime(0) : Dates.DateTime(ts_str)

    raw_labels = get(raw, "labels", Any[])
    lbls = String[string(l) for l in raw_labels]

    raw_data = get(raw, "data", Dict{String, Any}())

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
    scope_records = [_raw_to_scope_record(s) for s in raw_scopes]

    raw_refs = get(raw, "blob_refs", Any[])
    refs = String[string(r) for r in raw_refs]

    CommitRecord(
        get(raw, "session_label", ""),
        get(raw, "commit_label", ""),
        get(raw, "metadata", Dict{String, Any}()),
        scope_records,
        refs
    )
end
