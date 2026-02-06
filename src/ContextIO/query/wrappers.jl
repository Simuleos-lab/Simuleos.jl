# Wrapper structs holding loaded data with accessor methods
# Wrappers are immutable structs holding a copy of raw data

"""
    CommitWrapper

Wraps a single commit record (one JSONL line) from the tape.
"""
struct CommitWrapper
    raw::Dict{String, Any}
end

"""
    ScopeWrapper

Wraps a single scope from a commit.
"""
struct ScopeWrapper
    raw::Dict{String, Any}
end

"""
    VariableWrapper

Wraps a single variable from a scope.
"""
struct VariableWrapper
    name::String
    raw::Dict{String, Any}
end

"""
    BlobWrapper

Wraps deserialized blob data.
"""
struct BlobWrapper
    raw::Any
end

# CommitWrapper methods

"""
    session_label(c::CommitWrapper) -> String

Returns the session label for this commit.
"""
function session_label(c::CommitWrapper)::String
    get(c.raw, "session_label", "")
end

"""
    commit_label(c::CommitWrapper) -> String

Returns the commit label (if any) for this commit.
"""
function commit_label(c::CommitWrapper)::String
    get(c.raw, "commit_label", "")
end

"""
    metadata(c::CommitWrapper) -> Dict

Returns the metadata dictionary for this commit.
"""
function metadata(c::CommitWrapper)::Dict
    get(c.raw, "metadata", Dict{String, Any}())
end

"""
    scopes(c::CommitWrapper)

Returns an iterator of `ScopeWrapper` for all scopes in this commit.
"""
function scopes(c::CommitWrapper)
    raw_scopes = get(c.raw, "scopes", Any[])
    (ScopeWrapper(s) for s in raw_scopes)
end

"""
    blob_refs(c::CommitWrapper) -> Vector{String}

Returns the list of blob references in this commit.
"""
function blob_refs(c::CommitWrapper)::Vector{String}
    refs = get(c.raw, "blob_refs", Any[])
    String[string(r) for r in refs]
end

# ScopeWrapper methods

"""
    label(s::ScopeWrapper) -> String

Returns the label for this scope.
"""
function label(s::ScopeWrapper)::String
    get(s.raw, "label", "")
end

"""
    timestamp(s::ScopeWrapper) -> Dates.DateTime

Returns the timestamp for this scope.
"""
function timestamp(s::ScopeWrapper)::Dates.DateTime
    ts = get(s.raw, "timestamp", nothing)
    isnothing(ts) && return Dates.DateTime(0)
    Dates.DateTime(ts)
end

"""
    variables(s::ScopeWrapper)

Returns an iterator of `VariableWrapper` for all variables in this scope.
"""
function variables(s::ScopeWrapper)
    raw_vars = get(s.raw, "variables", Dict{String, Any}())
    (VariableWrapper(name, v) for (name, v) in raw_vars)
end

"""
    labels(s::ScopeWrapper) -> Vector{String}

Returns the context labels for this scope.
"""
function labels(s::ScopeWrapper)::Vector{String}
    lbls = get(s.raw, "labels", Any[])
    String[string(l) for l in lbls]
end

"""
    data(s::ScopeWrapper) -> Dict

Returns the context data for this scope.
"""
function data(s::ScopeWrapper)::Dict
    get(s.raw, "data", Dict{String, Any}())
end

# VariableWrapper methods

"""
    name(v::VariableWrapper) -> String

Returns the name of this variable.
"""
function name(v::VariableWrapper)::String
    v.name
end

"""
    src_type(v::VariableWrapper) -> String

Returns the source type string for this variable.
"""
function src_type(v::VariableWrapper)::String
    get(v.raw, "src_type", "")
end

"""
    value(v::VariableWrapper)

Returns the lite value of this variable, or nothing if not stored inline.
"""
function value(v::VariableWrapper)
    get(v.raw, "value", nothing)
end

"""
    blob_ref(v::VariableWrapper)

Returns the blob SHA1 reference, or nothing if not a blob.
"""
function blob_ref(v::VariableWrapper)
    get(v.raw, "blob_ref", nothing)
end

"""
    src(v::VariableWrapper) -> Symbol

Returns :local or :global indicating the variable's source.
"""
function src(v::VariableWrapper)::Symbol
    s = get(v.raw, "src", "local")
    Symbol(s)
end

# BlobWrapper methods

"""
    data(b::BlobWrapper)

Returns the actual deserialized Julia object.
"""
function data(b::BlobWrapper)
    b.raw
end
