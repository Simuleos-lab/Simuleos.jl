struct SC_HOOK
    query::Vector
    fun::Function
end

# MARK: SimuleosScopeVariable
@kwdef mutable struct SimuleosScopeVariable
    key::String
    val::Any = nothing
    src::Union{Nothing, Symbol} = nothing
end
    
# MARK: Scope
struct Scope
    sc::Dict{String, SimuleosScopeVariable}
end
Scope() = Scope(Dict())
