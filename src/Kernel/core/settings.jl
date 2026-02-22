# ============================================================
# settings.jl — Layered settings system (replaces UXLayers)
# ============================================================

const __MISSING__ = :__MISSING__

"""
    merge_settings(layers...) -> Dict{String, Any}

Merge settings layers with left-to-right priority (later layers override earlier).
All layers are Dict{String, Any}.
"""
function merge_settings(layers...)
    merged = Dict{String, Any}()
    for layer in layers
        merge!(merged, layer)
    end
    return merged
end

"""
    load_all_settings(simos::SimOs) -> Dict{String, Any}

Build the full settings Dict by merging (lowest to highest priority):
1. Home settings (~/.simuleos/settings.json)
2. Project settings (.simuleos/settings.json)
3. Environment variables (SIMULEOS_*)
4. Bootstrap dict (passed to sim_init!)
"""
function load_all_settings(simos::SimOs)
    layers = Dict{String, Any}[]

    # Layer 1: Home
    if !isnothing(simos.home)
        push!(layers, home_settings(simos.home))
    end

    # Layer 2: Project
    if !isnothing(simos.project)
        push!(layers, project_settings(simos.project))
    end

    # Layer 3: Environment
    push!(layers, env_settings())

    # Layer 4: Bootstrap
    push!(layers, _string_keys(simos.bootstrap))

    return merge_settings(layers...)
end

"""
    get_setting(simos::SimOs, key::String, default=nothing)

Get a setting value by dotted key.
"""
function get_setting(simos::SimOs, key::String, default=nothing)
    return get(simos.settings, key, default)
end

settings(simos::SimOs, key::String) = get_setting(simos, key, __MISSING__) === __MISSING__ ? error("Missing setting: $key") : get_setting(simos, key)
settings(simos::SimOs, key::String, default) = get_setting(simos, key, default)
