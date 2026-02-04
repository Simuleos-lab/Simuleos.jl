# Settings access for SimOS (UXLayers integration)
# This is the cold path - direct access to UXLayers

using UXLayers: UXLayerView

# Sentinel for missing values
const __MISSING__ = :__MISSING__

"""
    _init_ux_root!(os::SimOS)

Lazily initialize the UXLayers root view on first access.
"""
function _init_ux_root!(os::SimOS)
    if isnothing(os._ux_root)
        os._ux_root = UXLayerView("simuleos")
    end
    return os._ux_root
end

"""
    ux_root(os::SimOS)

Get the UXLayers root view, initializing if needed.
"""
function ux_root(os::SimOS)::UXLayerView
    return _init_ux_root!(os)
end

"""
    settings(os::SimOS, key::String)

Get a setting value from UXLayers. Errors if key not found.
"""
function settings(os::SimOS, key::String)
    view = ux_root(os)
    val = get(view, key, __MISSING__)
    if val === __MISSING__
        error("Setting not found: $key")
    end
    return val
end

"""
    settings(os::SimOS, key::String, default)

Get a setting value from UXLayers, returning default if not found.
"""
function settings(os::SimOS, key::String, default)
    view = ux_root(os)
    val = get(view, key, __MISSING__)
    if val === __MISSING__
        return default
    end
    return val
end
