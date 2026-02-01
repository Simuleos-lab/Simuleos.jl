# Core type definitions for Simuleos

using Dates

@kwdef struct ScopeVariable
    name::String
    type::String                              # string repr for JSON
    value::Union{Nothing, Any} = nothing      # only if lite
    blob_ref::Union{Nothing, String} = nothing # SHA1 hash if stored
end

struct Scope
    label::String
    timestamp::DateTime
    variables::Dict{String, ScopeVariable}
end

mutable struct Stage
    scopes::Vector{Scope}
    blob_refs::Set{String}
end

@kwdef mutable struct Session
    label::String
    root_dir::String           # .simuleos/ path
    stage::Stage
    meta::Dict{String, Any}    # git, julia version, etc.
    blob_set::Set{Symbol}      # vars marked for blob storage
end
