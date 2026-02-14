# Scoperias base constructors (all I0x)
# Runtime constructors for `Scope` now that struct definitions live in Core types.

# Empty scope
Scope() = Scope(String[], Dict{Symbol, ScopeVariable}(), Dict{Symbol, Any}())

# Scope with labels only
Scope(labels::Vector{String}) = Scope(labels, Dict{Symbol, ScopeVariable}(), Dict{Symbol, Any}())

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
        vars[k] = InMemoryScopeVariable(:global, _type_short(v), v)
    end
    for (k, v) in locals
        vars[k] = InMemoryScopeVariable(:local, _type_short(v), v)  # overrides globals
    end
    return Scope(labels, vars, Dict{Symbol, Any}())
end
