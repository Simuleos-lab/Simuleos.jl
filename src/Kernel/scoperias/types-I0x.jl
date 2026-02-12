# Scoperias — Scope runtime types (all I0x — pure data types)
# Scopes as runtime containers of raw Julia values.
# No blob classification, no disk I/O — those are Recorder concerns.

# ==================================
# ScopeVariable — a captured variable (raw value + source tag)
# ==================================

struct ScopeVariable
    val::Any
    src::Symbol  # :local or :global
end

# ==================================
# Scope — runtime container of named variables
# ==================================

mutable struct Scope
    labels::Vector{String}
    variables::Dict{Symbol, ScopeVariable}
end

# Empty scope
Scope() = Scope(String[], Dict{Symbol, ScopeVariable}())

# Scope with labels only
Scope(labels::Vector{String}) = Scope(labels, Dict{Symbol, ScopeVariable}())

# Single-label convenience
Scope(label::String) = Scope([label])

# Construct from raw capture dicts (locals override globals on collision)
function Scope(
    labels::Vector{String},
    locals::Dict{Symbol, Any},
    globals::Dict{Symbol, Any}
)
    vars = Dict{Symbol, ScopeVariable}()
    for (k, v) in globals
        vars[k] = ScopeVariable(v, :global)
    end
    for (k, v) in locals
        vars[k] = ScopeVariable(v, :local)  # overrides globals
    end
    Scope(labels, vars)
end
