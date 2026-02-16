# UXLayer initialization (I0x - pure, no SimOs dependency)

"""
    DEFAULTS

Built-in default settings. Lowest priority source.
"""
const DEFAULTS = Dict{String, Any}()

"""
    uxlayer_init(bootstrap::Dict{String, Any})::UXLayers.UXLayerView

I0x - pure

Initialize the UXLayer root view with bootstrap and ENV sources.
Called at Phase 0 of sim_init!, before project/home exist.

Sources at Phase 0 (priority order):
1. :runtime  — bootstrap dict (runtime user settings)
2. :env      — parsed from ENV

Defaults set via update_defaults!.
Local/global settings are added later after project/home init.
"""
function uxlayer_init(bootstrap::Dict{String, Any})::UXLayers.UXLayerView
    # Create root view
    ux = UXLayers.UXLayerView("simuleos")

    # Parse ENV
    env_settings = _simuleos_parse_env(ENV)

    # Load sources
    UXLayers.refresh!(ux,
        Dict(
            :runtime => bootstrap,
            :env => env_settings,
        ),
        [:runtime, :env]
    )

    # Set defaults
    UXLayers.update_defaults!(ux, DEFAULTS)

    # NOTE: built-in bootstrap slot left empty — :runtime source handles it.
    # Revise this decision later.

    return ux
end
