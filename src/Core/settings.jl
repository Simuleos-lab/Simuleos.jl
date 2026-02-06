# Settings access for SimOS (source-based resolution)
# Iterates through _sources in priority order, returns first hit

# Sentinel for missing values
const __MISSING__ = :__MISSING__

"""
    ux_root(os::Core.SimOS)

Get the UXLayers root view. Must call activate() first.
"""
function ux_root(os::Core.SimOS)::UXLayers.UXLayerView
    if isnothing(os._ux_root)
        error("Settings not initialized. Call Simuleos.activate(path, args) first.")
    end
    return os._ux_root
end

"""
    _resolve_setting(os::Core.SimOS, key::String)

Resolve a setting by checking sources in priority order.
Returns (found::Bool, value::Any).
"""
function _resolve_setting(os::Core.SimOS, key::String)
    for source in os._sources
        if haskey(source, key)
            return (true, source[key])
        end
    end
    return (false, nothing)
end

"""
    settings(os::Core.SimOS, key::String)

Get a setting value by checking sources in priority order.
Errors if key not found in any source.
"""
function settings(os::Core.SimOS, key::String)
    if isempty(os._sources)
        error("Settings not initialized. Call Simuleos.activate(path, args) first.")
    end

    found, val = Core._resolve_setting(os, key)
    if !found
        error("Setting not found: $key")
    end
    return val
end

"""
    settings(os::Core.SimOS, key::String, default)

Get a setting value by checking sources in priority order.
Returns default if key not found in any source.
"""
function settings(os::Core.SimOS, key::String, default)
    if isempty(os._sources)
        return default
    end

    found, val = Core._resolve_setting(os, key)
    if !found
        return default
    end
    return val
end
