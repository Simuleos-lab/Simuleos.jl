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
    parsed = Core.JSON3.read(content, Dict{String, Any})
    return parsed
end

# ==================================
# UXLayer Root Building
# ==================================

"""
    _build_ux_root!(os::Core.SimOS, args::Dict{String, Any})

Build the UXLayers root view with all sources in priority order.
Called at activate() time.

Sources (priority order, first hit wins):
1. args          - passed to activate()
2. bootstrap     - from SimOS constructor
3. local         - .simuleos/settings.json
4. global        - ~/.simuleos/settings.json
5. DEFAULTS      - built-in defaults
"""
function _build_ux_root!(os::Core.SimOS, args::Dict{String, Any})
    # Build source list in priority order
    sources = Dict{String, Any}[]

    # Priority 1: args (highest)
    push!(sources, args)

    # Priority 2: bootstrap from constructor
    push!(sources, os.bootstrap)

    # Priority 3: local project settings
    if !isnothing(os.project_root)
        local_path = joinpath(os.project_root, ".simuleos", "settings.json")
        push!(sources, Core._load_settings_json(local_path))
    else
        push!(sources, Dict{String, Any}())
    end

    # Priority 4: global user settings
    global_path = joinpath(os.home_path, "settings.json")
    push!(sources, Core._load_settings_json(global_path))

    # Priority 5: built-in defaults (lowest)
    push!(sources, Core.DEFAULTS)

    # Store sources for resolution
    os._sources = sources

    # Create UXLayerView (for compatibility, not used for resolution)
    os._ux_root = UXLayers.UXLayerView("simuleos")

    return os._ux_root
end

