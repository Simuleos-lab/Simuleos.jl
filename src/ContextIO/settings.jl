# Settings access for Session (cached UXLayers integration)
# This is the hot path - uses session cache, falls back to UXLayers on miss

using ..Core: Session, SimOS, __MISSING__, ux_root
import ..Core: settings  # Import to extend with Session methods

# Import Simuleos module for OS access (will be available at runtime)
# We use a function to defer the lookup

"""
    _get_os()

Get the global SimOS instance. Deferred to avoid circular dependency.
"""
function _get_os()::SimOS
    # Access Simuleos.OS via the parent module
    return Main.Simuleos.OS
end

"""
    settings(session::Session, key::String)

Get a setting value from session cache. On miss, fetches from UXLayers and caches.
Errors if key not found in UXLayers.
"""
function settings(session::Session, key::String)
    # Check cache first
    if haskey(session._settings_cache, key)
        cached = session._settings_cache[key]
        if cached === __MISSING__
            error("Setting not found: $key")
        end
        return cached
    end

    # Cache miss - fetch from UXLayers via OS
    os = _get_os()
    view = ux_root(os)
    val = get(view, key, __MISSING__)

    # Cache the result (including misses)
    session._settings_cache[key] = val

    if val === __MISSING__
        error("Setting not found: $key")
    end
    return val
end

"""
    settings(session::Session, key::String, default)

Get a setting value from session cache. On miss, fetches from UXLayers and caches.
Returns default if key not found.
"""
function settings(session::Session, key::String, default)
    # Check cache first
    if haskey(session._settings_cache, key)
        cached = session._settings_cache[key]
        if cached === __MISSING__
            return default
        end
        return cached
    end

    # Cache miss - fetch from UXLayers via OS
    os = _get_os()
    view = ux_root(os)
    val = get(view, key, __MISSING__)

    # Cache the result (including misses)
    session._settings_cache[key] = val

    if val === __MISSING__
        return default
    end
    return val
end

"""
    _reset_settings_cache!(session::Session)

Clear the settings cache. Called at @sim_session start.
"""
function _reset_settings_cache!(session::Session)
    empty!(session._settings_cache)
    return nothing
end
