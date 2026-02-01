# Core type definitions for Simuleos

using Dates

@kwdef struct ScopeVariable
    name::String
    type::String                              # string repr for JSON
    value::Union{Nothing, Any} = nothing      # only if lite
    blob_ref::Union{Nothing, String} = nothing # SHA1 hash if stored
    src::Symbol = :local                      # :local or :global
end

# Per-scope context (reset after each @sim_capture)
@kwdef mutable struct ScopeContext
    labels::Vector{String} = String[]
    data::Dict{Symbol, Any} = Dict{Symbol, Any}()
    blob_set::Set{Symbol} = Set{Symbol}()     # per-scope blob requests
end

struct Scope
    label::String
    timestamp::DateTime
    variables::Dict{String, ScopeVariable}
    context_labels::Vector{String}            # from @sim_context
    context_data::Dict{Symbol, Any}           # from @sim_context
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
    current_context::ScopeContext  # per-scope context (reset after capture)
end
