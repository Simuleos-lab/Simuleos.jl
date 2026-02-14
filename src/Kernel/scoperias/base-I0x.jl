# Scoperias base constructors (all I0x)
# Runtime constructors for `Scope` now that struct definitions live in Core types.

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
    return Scope(labels, vars)
end
