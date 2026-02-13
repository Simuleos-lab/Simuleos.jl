# Settings access for WorkSession (cache operations only)

"""
    _reset_settings_cache!(worksession::Kernel.WorkSession)

I1x — operates on `worksession._settings_cache`

Clear the settings cache. Called at @session_init start.
"""
function _reset_settings_cache!(worksession::Kernel.WorkSession)
    empty!(worksession._settings_cache)
    return nothing
end
