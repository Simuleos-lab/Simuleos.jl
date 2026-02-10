# Settings access for SessionRecorder (cache operations only)

"""
    _reset_settings_cache!(recorder::Kernel.SessionRecorder)

I1x — operates on `recorder._settings_cache`

Clear the settings cache. Called at @session_init start.
"""
function _reset_settings_cache!(recorder::Kernel.SessionRecorder)
    empty!(recorder._settings_cache)
    return nothing
end
