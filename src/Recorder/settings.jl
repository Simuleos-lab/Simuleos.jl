# Settings access for SessionRecorder (cached UXLayers-based resolution)
# This is the hot path - uses recorder cache, falls back to UXLayers on miss

import ..Core: settings  # Import to extend with SessionRecorder methods

"""
    settings(recorder::Core.SessionRecorder, key::String)

Get a setting value from recorder cache. On miss, resolves via UXLayers and caches.
Errors if key not found.
"""
function settings(recorder::Core.SessionRecorder, key::String)
    # Check cache first
    if haskey(recorder._settings_cache, key)
        cached = recorder._settings_cache[key]
        if cached === Core.__MISSING__
            error("Setting not found: $key")
        end
        return cached
    end

    # Cache miss - resolve via current_sim
    sim = Core._get_sim()
    try
        val = Core.settings(sim, key)
        recorder._settings_cache[key] = val
        return val
    catch e
        if e isa KeyError || e isa ErrorException
            recorder._settings_cache[key] = Core.__MISSING__
            error("Setting not found: $key")
        end
        rethrow()
    end
end

"""
    settings(recorder::Core.SessionRecorder, key::String, default)

Get a setting value from recorder cache. On miss, resolves via UXLayers and caches.
Returns default if key not found.
"""
function settings(recorder::Core.SessionRecorder, key::String, default)
    # Check cache first
    if haskey(recorder._settings_cache, key)
        cached = recorder._settings_cache[key]
        if cached === Core.__MISSING__
            return default
        end
        return cached
    end

    # Cache miss - resolve via current_sim
    sim = Core._get_sim()
    val = Core.settings(sim, key, default)

    # Cache the result (including misses as __MISSING__)
    recorder._settings_cache[key] = (val === default) ? Core.__MISSING__ : val

    return val
end

"""
    _reset_settings_cache!(recorder::Core.SessionRecorder)

Clear the settings cache. Called at @session_init start.
"""
function _reset_settings_cache!(recorder::Core.SessionRecorder)
    empty!(recorder._settings_cache)
    return nothing
end
