# UXLayer root building (all I2x - explicit SimOs integration)

"""
    _buildux!(sim::SimOs, bootstrap::Dict{String, Any})

I2x - reads `sim.project`, `sim.home`, `sim.bootstrap`; writes `sim.ux`

Build the UXLayers root view with all sources in priority order.
Called at sim_activate() time.

Sources (priority order, first hit wins):
1. bootstrap     - passed to sim_activate()
2. local         - .simuleos/settings.json
3. global        - ~/.simuleos/settings.json

Bootstrap and defaults are set separately via update_bootstrap!() and update_defaults!().
"""
function _buildux!(sim::SimOs, bootstrap::Dict{String, Any})
    # Create UXLayerView root
    ux = UXLayers.UXLayerView("simuleos")

    # Load sources in priority order (highest to lowest)
    # Priority 2: local project settings
    local_settings = if !isnothing(sim.project)
        _load_settings_json(proj_settings_path(sim))
    else
        Dict{String, Any}()
    end

    # Priority 3: global user settings
    global_settings = if !isnothing(sim.home)
        _load_settings_json(home_settings_path(sim))
    else
        Dict{String, Any}()
    end

    # Load all sources into UXLayers
    UXLayers.refresh!(ux,
        Dict(
            :bootstrap => bootstrap,
            :local => local_settings,
            :global => global_settings,
        ),
        [:bootstrap, :local, :global]  # Priority order
    )

    # Set bootstrap and defaults
    UXLayers.update_bootstrap!(ux, sim.bootstrap)
    UXLayers.update_defaults!(ux, DEFAULTS)

    sim.ux = ux
    return ux
end
