# Global session state for Simuleos

__SIM_SESSION__::Union{Nothing, Session} = nothing

function _reset_session!()
    global __SIM_SESSION__ = nothing
end

function _get_session()
    isnothing(__SIM_SESSION__) && error("No active Simuleos session. Use @sim_session first.")
    return __SIM_SESSION__
end
