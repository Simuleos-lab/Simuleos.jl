# UXLayer - Settings sources configuration
# Manages multiple settings sources with priority-based resolution

# ==================================
# Built-in Defaults (lowest priority)
# ==================================

"""
    DEFAULTS

Built-in default settings. Lowest priority source.
"""
const DEFAULTS = Dict{String, Any}(
    # Add default settings here as needed
    # "max_blob_size" => 1048576,
    # "compression" => true,
)

# ==================================
# Source Loading
# ==================================

"""
    _load_settings_json(path::String)::Dict{String, Any}

I0x — pure file I/O

Load settings from a JSON file. Returns empty dict if file doesn't exist.
Errors on malformed JSON.
"""
function _load_settings_json(path::String)::Dict{String, Any}
    if !isfile(path)
        return Dict{String, Any}()
    end

    content = read(path, String)
    if isempty(strip(content))
        return Dict{String, Any}()
    end

    # Parse JSON - will error on malformed JSON
    parsed = JSON3.read(content, Dict{String, Any})
    return parsed
end

# ==================================
# UXLayer Root Building
# ==================================

"""
    _buildux!(sim::SimOs, args::Dict{String, Any})

I2x — reads `sim.project_root`, `sim.home_path`, `sim.bootstrap`; writes `sim.ux`

Build the UXLayers root view with all sources in priority order.
Called at sim_activate() time.

Sources (priority order, first hit wins):
1. args          - passed to sim_activate()
2. local         - .simuleos/settings.json
3. global        - ~/.simuleos/settings.json

Bootstrap and defaults are set separately via update_bootstrap!() and update_defaults!().
"""
function _buildux!(sim::SimOs, args::Dict{String, Any})
    # Create UXLayerView root
    ux = UXLayers.UXLayerView("simuleos")

    # Load sources in priority order (highest to lowest)
    # Priority 2: local project settings
    local_settings = if !isnothing(sim.project_root)
        _load_settings_json(local_settings_path(sim.project_root))
    else
        Dict{String, Any}()
    end

    # Priority 3: global user settings
    global_settings = _load_settings_json(global_settings_path(sim.home_path))

    # Load all sources into UXLayers
    UXLayers.refresh!(ux,
        Dict(
            :args => args,
            :local => local_settings,
            :global => global_settings,
        ),
        [:args, :local, :global]  # Priority order
    )

    # Set bootstrap and defaults
    UXLayers.update_bootstrap!(ux, sim.bootstrap)
    UXLayers.update_defaults!(ux, DEFAULTS)

    sim.ux = ux
    return ux
end
