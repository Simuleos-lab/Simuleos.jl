# Session management and global state

using ..Core: Session

# Global session state
__SIM_SESSION__::Union{Nothing, Session} = nothing

function _reset_session!()
    global __SIM_SESSION__ = nothing
end

function _get_session()
    isnothing(__SIM_SESSION__) && error("No active Simuleos session. Use @sim_session first.")
    return __SIM_SESSION__
end

function _set_session!(session::Session)
    global __SIM_SESSION__ = session
end
