# ============================================================
# WorkSession/settings.jl — Session-level settings
# ============================================================

"""
    session_setting(ws::_Kernel.WorkSession, key::String, default=nothing)

Get a cached session setting.
"""
function session_setting(ws::_Kernel.WorkSession, key::String, default=nothing)
    # Check session cache first
    if haskey(ws._settings_cache, key)
        return ws._settings_cache[key]
    end

    # Fall back to global settings
    sim = _Kernel._get_sim_or_nothing()
    if !isnothing(sim)
        return _Kernel.get_setting(sim, key, default)
    end
    return default
end

"""
    session_setting!(ws::_Kernel.WorkSession, key::String, value)

Set a session-level setting (cached only, not persisted).
"""
function session_setting!(ws::_Kernel.WorkSession, key::String, value)
    ws._settings_cache[key] = value
end

function _reset_settings_cache!(ws::_Kernel.WorkSession)
    empty!(ws._settings_cache)
    return ws
end

settings(ws::_Kernel.WorkSession, key::String) = session_setting(ws, key, _Kernel.__MISSING__) === _Kernel.__MISSING__ ? error("Missing setting: $key") : session_setting(ws, key)
settings(ws::_Kernel.WorkSession, key::String, default) = session_setting(ws, key, default)
