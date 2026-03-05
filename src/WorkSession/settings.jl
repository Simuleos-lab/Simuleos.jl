# ============================================================
# WorkSession/settings.jl — Session-level settings
# ============================================================

"""
    session_setting(ws::_Kernel.WorkSession, key::String, default=nothing)

Get an effective setting for the active session from the shared settings stack.
"""
function session_setting(ws::_Kernel.WorkSession, key::String, default=nothing)
    _ = ws
    sim = _Kernel._get_simos_or_nothing()
    if !isnothing(sim)
        return _Kernel.settings(sim, key, default)
    end
    return default
end

"""
    session_setting!(ws::_Kernel.WorkSession, key::String, value)

Set a session-level setting on the shared `:session` settings layer.
"""
function session_setting!(ws::_Kernel.WorkSession, key::String, value)
    sim = _Kernel._get_simos_or_nothing()
    isnothing(sim) && error("Simuleos not initialized. Call `sim_init!()` first.")
    sim.worksession === ws || error("WorkSession is not the active session in SimOs.")
    _Kernel.settings_layer_set!(sim, :session, key, value)
    return ws
end

function _reset_session_settings!(ws::_Kernel.WorkSession)
    _ = ws
    sim = _Kernel._get_simos_or_nothing()
    isnothing(sim) && return ws
    _Kernel.settings_layer_clear!(sim, :session)
    return ws
end

function settings(ws::_Kernel.WorkSession, key::String)
    value = session_setting(ws, key, _Kernel.__MISSING__)
    value === _Kernel.__MISSING__ && error("Missing setting: $key")
    return value
end
settings(ws::_Kernel.WorkSession, key::String, default) = session_setting(ws, key, default)
