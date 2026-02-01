# TODO/ consider this for further srcs
# Base.isexported, Base.ispublic, Base.@locals, @__MODULE__.

# MARK: ScopeVariable
@kwdef mutable struct ScopeVariable
    key::String
    val::Any = nothing
    jl_type::Type # TAI/ maybe store an string
    src::Union{Nothing, Symbol} = nothing
    st_class::Union{Nothing, Symbol} = nothing
    st_hash::Union{Nothing, String} = nothing
end

# MARK: Scope
struct Scope
    sc_hash::Union{String, Nothing}
    sc::Dict{String, ScopeVariable}
end
Scope(sc::Dict) = Scope(st_blob_hash(sc), sc)
Scope() = Scope(nothing, Dict())

# MARK: ScopeTape
struct ScopeTape

    # setup
    root::String

    # Handle recording into the tape
    recording_scope_cache::OrderedDict{String, Scope}
    recording_blob_cache::Dict{String, Any}

    # Handle reading the tape
    reading_scope_cache::OrderedDict{String, Scope}
    reading_blob_cache::Dict{String, Any}
    
    # meta (session data)
    meta::Dict{String, Any}

    # extras (transient data)
    extras::Dict{String, Any}
    
    ScopeTape(root::String) = new(root, OrderedDict(), Dict(), OrderedDict(), Dict(), Dict(), Dict())

end

#=
    TODO/ implement a js/ts object interface
    Define a subset of a Scope...
=#
struct ScopeRule
    include_rules::Array
    exclude_rules::Array
end

