# Loading functions for tape and blob data
# Constructs typed Record objects from raw data

# ==================================
# Record constructors from raw Dict data
# ==================================

function _raw_to_variable_record(name::String, raw::Dict{String, Any})::Core.VariableRecord
    Core.VariableRecord(
        name,
        get(raw, "src_type", ""),
        get(raw, "value", nothing),
        get(raw, "blob_ref", nothing),
        Symbol(get(raw, "src", "local"))
    )
end

function _raw_to_scope_record(raw::Dict{String, Any})::Core.ScopeRecord
    raw_vars = get(raw, "variables", Dict{String, Any}())
    vars = [_raw_to_variable_record(name, v) for (name, v) in raw_vars]

    ts_str = get(raw, "timestamp", nothing)
    ts = isnothing(ts_str) ? Dates.DateTime(0) : Dates.DateTime(ts_str)

    raw_labels = get(raw, "labels", Any[])
    lbls = String[string(l) for l in raw_labels]

    raw_data = get(raw, "data", Dict{String, Any}())

    Core.ScopeRecord(
        get(raw, "label", ""),
        ts,
        vars,
        lbls,
        raw_data
    )
end

function _raw_to_commit_record(raw::Dict{String, Any})::Core.CommitRecord
    raw_scopes = get(raw, "scopes", Any[])
    scope_records = [_raw_to_scope_record(s) for s in raw_scopes]

    raw_refs = get(raw, "blob_refs", Any[])
    refs = String[string(r) for r in raw_refs]

    Core.CommitRecord(
        get(raw, "session_label", ""),
        get(raw, "commit_label", ""),
        get(raw, "metadata", Dict{String, Any}()),
        scope_records,
        refs
    )
end

# ==================================
# Raw tape iteration
# ==================================

"""
    iterate_raw_tape(handler::TapeHandler)

Returns a lazy iterator that yields one Dict per JSONL line.
Each Dict represents a commit record.
"""
function iterate_raw_tape(handler::Core.TapeHandler)
    path = _tape_path(handler)
    isfile(path) || return Dict{String, Any}[]
    _TapeIterator(path)
end

# Custom iterator for lazy line-by-line reading
struct _TapeIterator
    path::String
end

function Base.iterate(ti::_TapeIterator)
    io = open(ti.path, "r")
    state = (io,)
    iterate(ti, state)
end

function Base.iterate(::_TapeIterator, state)
    io = state[1]
    while !eof(io)
        line = readline(io)
        isempty(strip(line)) && continue
        parsed = JSON3.read(line, Dict{String, Any})
        return (parsed, state)
    end
    close(io)
    return nothing
end

Base.IteratorSize(::Type{_TapeIterator}) = Base.SizeUnknown()
Base.eltype(::Type{_TapeIterator}) = Dict{String, Any}

# ==================================
# Typed tape iteration (CommitRecord)
# ==================================

"""
    iterate_tape(handler::TapeHandler)

Returns a lazy iterator that yields `CommitRecord` objects.
"""
function iterate_tape(handler::Core.TapeHandler)
    (_raw_to_commit_record(raw) for raw in iterate_raw_tape(handler))
end

import Base.collect
function Base.collect(::Type{Vector{Core.CommitRecord}}, handler::Core.TapeHandler)
    collect(iterate_tape(handler))
end

# TapeHandler convenience iteration (defaults to typed CommitRecord)

function Base.iterate(handler::Core.TapeHandler)
    iter = iterate_tape(handler)
    result = iterate(iter)
    isnothing(result) && return nothing
    (result[1], (iter, result[2]))
end

function Base.iterate(::Core.TapeHandler, state)
    iter, inner_state = state
    result = iterate(iter, inner_state)
    isnothing(result) && return nothing
    (result[1], (iter, result[2]))
end

Base.IteratorSize(::Type{Core.TapeHandler}) = Base.SizeUnknown()
Base.eltype(::Type{Core.TapeHandler}) = Core.CommitRecord

# ==================================
# Raw blob loading
# ==================================

"""
    load_raw_blob(handler::BlobHandler) -> Any

Deserializes and returns the blob data as a Julia object.
"""
function load_raw_blob(handler::Core.BlobHandler)
    path = _blob_path(handler)
    open(path, "r") do io
        Serialization.deserialize(io)
    end
end

# ==================================
# Typed blob loading (BlobRecord)
# ==================================

"""
    load_blob(handler::BlobHandler) -> BlobRecord

Loads and wraps the blob data.
"""
function load_blob(handler::Core.BlobHandler)::Core.BlobRecord
    Core.BlobRecord(load_raw_blob(handler))
end
