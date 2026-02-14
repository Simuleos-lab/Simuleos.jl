# ScopeTapes record model (all I0x)

"""
    CommitRecord

Typed commit record for scope tape payloads.
"""
struct CommitRecord
    commit_label::String
    metadata::Dict{String, Any}
    scopes::Vector{Any}       # Holds ScopeRecord objects
    blob_refs::Vector{String}
end

"""
    ScopeRecord

Typed scope record inside a commit.
"""
struct ScopeRecord
    label::String
    timestamp::Dates.DateTime
    variables::Vector{Any}    # Holds VariableRecord objects
    labels::Vector{String}
    data::Dict{String, Any}
end

"""
    VariableRecord

Typed variable payload in a scope record.
"""
struct VariableRecord
    name::String
    src_type::String
    value::Any
    blob_ref::Union{Nothing, String}
    src::Symbol
end
