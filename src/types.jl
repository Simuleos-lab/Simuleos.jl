# Core type definitions for Simuleos

using Dates

@kwdef struct ScopeVariable
    name::String
    src_type::String                          # string repr for JSON, truncated to 25 chars
    value::Union{Nothing, Any} = nothing      # only if lite
    blob_ref::Union{Nothing, String} = nothing # SHA1 hash if stored
    src::Symbol = :local                      # :local or :global
end

@kwdef mutable struct Scope
    label::String = ""
    timestamp::DateTime = now()
    isopen::Bool = true                       # lifecycle tracking
    variables::Dict{String, ScopeVariable} = Dict{String, ScopeVariable}()
    labels::Vector{String} = String[]         # context labels from @sim_context
    data::Dict{Symbol, Any} = Dict{Symbol, Any}()  # context data from @sim_context
    blob_set::Set{Symbol} = Set{Symbol}()     # per-scope blob requests
end

@kwdef mutable struct Stage
    scopes::Vector{Scope} = Scope[]
    current_scope::Scope = Scope()            # explicit open scope
end

@kwdef mutable struct Session
    label::String
    root_dir::String           # .simuleos/ path
    stage::Stage
    meta::Dict{String, Any}    # git, julia version, etc.
    simignore_rules::Vector{Dict{Symbol, Any}} = Dict{Symbol, Any}[]
end
