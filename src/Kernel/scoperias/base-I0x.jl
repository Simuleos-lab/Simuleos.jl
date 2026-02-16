# Scoperias base constructors (all I0x)
# Runtime constructors for `SimuleosScope` now that struct definitions live in Core types.

# Empty scope
SimuleosScope() = SimuleosScope(String[], Dict{Symbol, ScopeVariable}(), Dict{Symbol, Any}())

# SimuleosScope with labels only
SimuleosScope(labels::Vector{String}) = SimuleosScope(labels, Dict{Symbol, ScopeVariable}(), Dict{Symbol, Any}())

# Single-label convenience
SimuleosScope(label::String) = SimuleosScope([label])

# Construct from raw capture dicts (locals override globals on collision)
function SimuleosScope(
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
    return SimuleosScope(labels, vars, Dict{Symbol, Any}())
end
