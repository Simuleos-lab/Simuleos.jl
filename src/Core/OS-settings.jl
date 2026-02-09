# Settings access for SimOs (UXLayers-based resolution)
# Uses UXLayerView for multi-source settings with priority ordering

# Sentinel for missing values
const __MISSING__ = :__MISSING__

"""
    ux_root(sim::Core.SimOs)

Get the UXLayers root view. Must call sim_activate() first.
"""
function ux_root(sim::Core.SimOs)::UXLayers._uxLayerView
    if isnothing(sim.ux)
        error("Settings not initialized. Call Simuleos.sim_activate(path, args) first.")
    end
    return sim.ux
end

"""
    settings(sim::Core.SimOs, key::String)

Get a setting value via UXLayers.
Errors if key not found.
"""
function settings(sim::Core.SimOs, key::String)
    ux = Core.ux_root(sim)
    return ux[:, key]  # Strict access, errors if not found
end

"""
    settings(sim::Core.SimOs, key::String, default)

Get a setting value via UXLayers.
Returns default if key not found.
"""
function settings(sim::Core.SimOs, key::String, default)
    ux = Core.ux_root(sim)
    return get(ux, key, default)
end
