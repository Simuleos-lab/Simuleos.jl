# Settings access for SessionRecorder (cached UXLayers-based resolution)
# This is the hot path - uses recorder cache, falls back to UXLayers on miss

import ..Kernel: settings  # Import to extend with SessionRecorder methods

"""
    settings(recorder::Kernel.SessionRecorder, key::String)

I1x/I3x — reads `recorder._settings_cache`; on miss falls back via `_get_sim()` → `SIMOS[].ux`

Get a setting value from recorder cache. On miss, resolves via UXLayers and caches.
Errors if key not found.
"""
function settings(recorder::Kernel.SessionRecorder, key::String)
    # Check cache first
    if haskey(recorder._settings_cache, key)
        cached = recorder._settings_cache[key]
        if cached === Kernel.__MISSING__
            error("Setting not found: $key")
        end
        return cached
    end

    # Cache miss - resolve via SIMOS
    sim = Kernel._get_sim()
    try
        val = Kernel.settings(sim, key)
        recorder._settings_cache[key] = val
        return val
    catch e
        if e isa KeyError || e isa ErrorException
            recorder._settings_cache[key] = Kernel.__MISSING__
            error("Setting not found: $key")
        end
        rethrow()
    end
end

"""
    settings(recorder::Kernel.SessionRecorder, key::String, default)

I1x/I3x — reads `recorder._settings_cache`; on miss falls back via `_get_sim()` → `SIMOS[].ux`

Get a setting value from recorder cache. On miss, resolves via UXLayers and caches.
Returns default if key not found.
"""
function settings(recorder::Kernel.SessionRecorder, key::String, default)
    # Check cache first
    if haskey(recorder._settings_cache, key)
        cached = recorder._settings_cache[key]
        if cached === Kernel.__MISSING__
            return default
        end
        return cached
    end

    # Cache miss - resolve via SIMOS
    sim = Kernel._get_sim()
    val = Kernel.settings(sim, key, default)

    # Cache the result (including misses as __MISSING__)
    recorder._settings_cache[key] = (val === default) ? Kernel.__MISSING__ : val

    return val
end

"""
    _reset_settings_cache!(recorder::Kernel.SessionRecorder)

I1x — operates on `recorder._settings_cache`

Clear the settings cache. Called at @session_init start.
"""
function _reset_settings_cache!(recorder::Kernel.SessionRecorder)
    empty!(recorder._settings_cache)
    return nothing
end
