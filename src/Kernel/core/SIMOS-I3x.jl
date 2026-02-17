# SIMOS global state (all I3x - uses SIMOS[])

# Single global: SIMOS[].
const SIMOS = Ref{Union{Nothing, SimOs}}(nothing)

"""
    set_sim!(new_sim::SimOs)

I3x — writes `SIMOS[]`

Replace the global SimOs instance. Used for testing.
"""
function set_sim!(new_sim::SimOs)
    SIMOS[] = new_sim
    return SIMOS[]
end

"""
    sim_reset!()

I3x — writes `SIMOS[]`

Reset the global SimOs instance to nothing.
Call before `sim_init!()` to re-initialize with different bootstrap.
"""
function sim_reset!()
    SIMOS[] = nothing
    return nothing
end

"""
    _get_sim()

I3x — reads `SIMOS[]`

Get the current SimOs instance, error if not initialized.
"""
function _get_sim()::SimOs
    sim = SIMOS[]
    isnothing(sim) && error("No Simuleos instance active. Call Simuleos.sim_init!() first.")
    return sim
end

"""
    sim_init!(; bootstrap::Dict{String, Any} = Dict{String, Any}())

I3x — manages `SIMOS[]`

Public entrypoint. Creates or reuses the global `SimOs` and delegates to
`sim_init!(simos; bootstrap)`. Lazy — cheap to call multiple times.
To re-initialize with different bootstrap, call `sim_reset!()` first.
"""
function sim_init!(; 
        bootstrap::Dict{String, Any} = Dict{String, Any}(), 
        _nukeFirst = true
    )
    sim = SIMOS[]
    if isnothing(sim)
        sim = SimOs(; bootstrap)
        SIMOS[] = sim
    end
    sim_init!(sim; bootstrap, _nukeFirst)
    return nothing
end
