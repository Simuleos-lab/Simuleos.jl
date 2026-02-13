# Settings access for WorkSession (cached UXLayers-based resolution)
# This is the hot path - uses work-session cache, falls back to UXLayers on miss

import ..Kernel: settings  # Import to extend with WorkSession methods

"""
    settings(worksession::Kernel.WorkSession, key::String)

I3x — reads `worksession._settings_cache`; on miss falls back via `_get_sim()` → `SIMOS[].ux`

Get a setting value from work-session cache. On miss, resolves via UXLayers and caches.
Errors if key not found.
"""
function settings(worksession::Kernel.WorkSession, key::String)
    # Check cache first
    if haskey(worksession._settings_cache, key)
        cached = worksession._settings_cache[key]
        if cached === Kernel.__MISSING__
            error("Setting not found: $key")
        end
        return cached
    end

    # Cache miss - resolve via SIMOS
    sim = Kernel._get_sim()
    try
        val = Kernel.settings(sim, key)
        worksession._settings_cache[key] = val
        return val
    catch e
        if e isa KeyError || e isa ErrorException
            worksession._settings_cache[key] = Kernel.__MISSING__
            error("Setting not found: $key")
        end
        rethrow()
    end
end

"""
    settings(worksession::Kernel.WorkSession, key::String, default)

I3x — reads `worksession._settings_cache`; on miss falls back via `_get_sim()` → `SIMOS[].ux`

Get a setting value from work-session cache. On miss, resolves via UXLayers and caches.
Returns default if key not found.
"""
function settings(worksession::Kernel.WorkSession, key::String, default)
    # Check cache first
    if haskey(worksession._settings_cache, key)
        cached = worksession._settings_cache[key]
        if cached === Kernel.__MISSING__
            return default
        end
        return cached
    end

    # Cache miss - resolve via SIMOS
    sim = Kernel._get_sim()
    val = Kernel.settings(sim, key, default)

    # Cache the result (including misses as __MISSING__)
    worksession._settings_cache[key] = (val === default) ? Kernel.__MISSING__ : val

    return val
end
