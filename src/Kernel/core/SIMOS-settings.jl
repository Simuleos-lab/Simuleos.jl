# Settings access for SimOs (UXLayers-based resolution)
# Uses UXLayerView for multi-source settings with priority ordering

# Sentinel for missing values
const __MISSING__ = :__MISSING__

"""
    ux_root(sim::SimOs)

I2x — reads `sim.ux`

Get the UXLayers root view. Must call sim_activate() first.
"""
function ux_root(sim::SimOs)::UXLayers.UXLayerView
    if isnothing(sim.ux)
        error("Settings not initialized. Call Simuleos.sim_activate(path, args) first.")
    end
    return sim.ux
end

"""
    settings(sim::SimOs, key::String)

I2x — reads `sim.ux`

Get a setting value via UXLayers.
Errors if key not found.
"""
function settings(sim::SimOs, key::String)
    ux = ux_root(sim)
    return ux[:, key]  # Strict access, errors if not found
end

"""
    settings(sim::SimOs, key::String, default)

I2x — reads `sim.ux`

Get a setting value via UXLayers.
Returns default if key not found.
"""
function settings(sim::SimOs, key::String, default)
    ux = ux_root(sim)
    return get(ux, key, default)
end
