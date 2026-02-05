# Settings access for Session (cached source-based resolution)
# This is the hot path - uses session cache, falls back to sources on miss

using ..Core: Session, SimOS, __MISSING__, _resolve_setting
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

Get a setting value from session cache. On miss, resolves from sources and caches.
Errors if key not found in any source.
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

    # Cache miss - resolve from sources via OS
    os = _get_os()
    found, val = _resolve_setting(os, key)

    # Cache the result (including misses)
    session._settings_cache[key] = found ? val : __MISSING__

    if !found
        error("Setting not found: $key")
    end
    return val
end

"""
    settings(session::Session, key::String, default)

Get a setting value from session cache. On miss, resolves from sources and caches.
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

    # Cache miss - resolve from sources via OS
    os = _get_os()
    found, val = _resolve_setting(os, key)

    # Cache the result (including misses)
    session._settings_cache[key] = found ? val : __MISSING__

    if !found
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
