# ============================================================
# stack.jl — Core settings stack model and access API
# ============================================================

"""
    _settings_layer_source_tag(layer::SettingsLayer) -> String

Derive the default source tag for bulk-loaded keys from the layer's origin metadata.
Prefers `origin["path"]` (file-backed), then `origin["source"]`, then the layer name.
"""
function _settings_layer_source_tag(layer::SettingsLayer)::String
    path = get(layer.origin, "path", nothing)
    if !isnothing(path)
        s = String(path)
        isempty(s) || return s
    end
    source = get(layer.origin, "source", nothing)
    if !isnothing(source)
        s = String(source)
        isempty(s) || return s
    end
    return string(layer.name)
end

"""
    _settings_fill_key_origin!(layer::SettingsLayer) -> SettingsLayer

Populate `key_origin` for every key in `layer.data` using the layer's source tag.
Existing entries in `key_origin` are preserved (only missing keys are filled).
"""
function _settings_fill_key_origin!(layer::SettingsLayer)::SettingsLayer
    isempty(layer.data) && return layer
    tag = _settings_layer_source_tag(layer)
    for k in keys(layer.data)
        haskey(layer.key_origin, k) && continue
        layer.key_origin[k] = tag
    end
    return layer
end

"""
    SettingsLayer(; name, kind, data=Dict(), is_mutable=false, persistent=false, origin=Dict(), key_origin=nothing)

Convenience constructor that normalizes metadata/data dictionaries to string keys.
When `key_origin` is `nothing` (default), auto-fills per-key origins from the layer's origin metadata.
"""
function SettingsLayer(;
        name::Symbol,
        kind::Symbol,
        data = Dict{String, Any}(),
        is_mutable::Bool = false,
        persistent::Bool = false,
        origin = Dict{String, Any}(),
        key_origin = nothing,
    )
    data isa AbstractDict || error("SettingsLayer `data` must be a Dict-like object.")
    origin isa AbstractDict || error("SettingsLayer `origin` must be a Dict-like object.")
    ko = isnothing(key_origin) ? Dict{String, String}() : Dict{String, String}(key_origin)
    layer = SettingsLayer(
        name,
        kind,
        is_mutable,
        persistent,
        _string_keys(origin),
        _string_keys(data),
        ko,
    )
    isnothing(key_origin) && _settings_fill_key_origin!(layer)
    return layer
end

"""
    SettingsStack(; layers=SettingsLayer[], effective=Dict(), effective_missing=Set(), effective_version=version, effective_complete=false, registry=Dict(), registry_alias_to_canonical=Dict(), version=0)

Convenience constructor for the layered settings stack.
"""
function SettingsStack(;
        layers::Vector{SettingsLayer} = SettingsLayer[],
        effective::Dict{String, Any} = Dict{String, Any}(),
        effective_missing::Set{String} = Set{String}(),
        version::Int = 0,
        effective_version::Int = version,
        effective_complete::Bool = false,
        registry::Dict{String, SettingsRegistryEntry} = Dict{String, SettingsRegistryEntry}(),
        registry_alias_to_canonical::Dict{String, String} = Dict{String, String}(),
    )
    return SettingsStack(
        layers,
        effective,
        effective_missing,
        effective_version,
        effective_complete,
        registry,
        registry_alias_to_canonical,
        version,
    )
end

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
    _settings_validate_key(key::String) -> String

Normalize and validate a settings key used in dotted-key helpers.
"""
function _settings_validate_key(key::String)::String
    s = strip(key)
    isempty(s) && error("Settings key cannot be empty.")
    startswith(s, ".") && error("Settings key cannot start with `.`: $(repr(key))")
    endswith(s, ".") && error("Settings key cannot end with `.`: $(repr(key))")
    occursin("..", s) && error("Settings key cannot contain `..`: $(repr(key))")
    return s
end

const _SETTINGS_FLATTEN_MAX_DEPTH = 32

function _settings_flatten_into!(
        out::Dict{String, Any},
        data::AbstractDict,
        prefix::String = "",
        depth::Int = 0,
        max_depth::Int = _SETTINGS_FLATTEN_MAX_DEPTH,
    )::Dict{String, Any}
    depth > max_depth && error("Settings nesting depth exceeds maximum `$(max_depth)` while flattening.")
    for (k, v) in data
        key_seg = _settings_validate_key(_to_string_key(k))
        full_key = isempty(prefix) ? key_seg : string(prefix, ".", key_seg)

        if v isa AbstractDict
            _settings_flatten_into!(out, _string_keys(v), full_key, depth + 1, max_depth)
            continue
        end

        haskey(out, full_key) && error("Duplicate settings key after flattening: $(full_key)")
        out[full_key] = v
    end
    return out
end

"""
    _settings_flatten_dict(data::AbstractDict) -> Dict{String, Any}

Flatten a nested settings object into dotted-key form.
"""
function _settings_flatten_dict(
        data::AbstractDict;
        max_depth::Int = _SETTINGS_FLATTEN_MAX_DEPTH,
    )::Dict{String, Any}
    max_depth < 0 && error("`max_depth` must be >= 0 (got $(max_depth)).")
    out = Dict{String, Any}()
    _settings_flatten_into!(out, _string_keys(data), "", 0, max_depth)
    return out
end

"""
    _settings_unflatten_dict(data::AbstractDict) -> Dict{String, Any}

Expand a dotted-key settings object into nested Dict form.
Conflicting key paths raise an error.
"""
function _settings_unflatten_dict(data::AbstractDict)::Dict{String, Any}
    out = Dict{String, Any}()
    for (k, v) in data
        key = _settings_validate_key(_to_string_key(k))
        parts = split(key, '.')
        any(isempty, parts) && error("Invalid dotted settings key: $(repr(key))")

        node = out
        for part in parts[1:end-1]
            if haskey(node, part)
                child = node[part]
                child isa AbstractDict || error("Settings path conflict at `$(part)` in key `$(key)`.")
                node = child
            else
                child = Dict{String, Any}()
                node[part] = child
                node = child
            end
        end

        leaf = parts[end]
        if haskey(node, leaf)
            existing = node[leaf]
            existing isa AbstractDict &&
                error("Settings path conflict: object/scalar collision at key `$(key)`.")
            error("Duplicate settings key during unflatten: `$(key)`.")
        end
        node[leaf] = v
    end
    return out
end

function _settings_stack_layer_index(stack::SettingsStack, name::Symbol)::Union{Nothing, Int}
    return findfirst(layer -> layer.name == name, stack.layers)
end

function _settings_stack_layer(stack::SettingsStack, name::Symbol)::Union{Nothing, SettingsLayer}
    idx = _settings_stack_layer_index(stack, name)
    return isnothing(idx) ? nothing : stack.layers[idx]
end

function _settings_stack_ensure_cache_epoch!(stack::SettingsStack)::SettingsStack
    if stack.effective_version != stack.version
        empty!(stack.effective)
        empty!(stack.effective_missing)
        stack.effective_complete = false
        stack.effective_version = stack.version
    end
    return stack
end

function _settings_stack_invalidate_effective!(stack::SettingsStack; bump_version::Bool = true)::SettingsStack
    bump_version && (stack.version += 1)
    empty!(stack.effective)
    empty!(stack.effective_missing)
    stack.effective_complete = false
    stack.effective_version = stack.version
    return stack
end

function _settings_stack_rebuild!(stack::SettingsStack)::SettingsStack
    # Phase 1/2 semantics: invalidate the lazy effective cache and bump version.
    _settings_stack_invalidate_effective!(stack; bump_version = true)
    return stack
end

function _settings_stack_resolve_and_cache!(stack::SettingsStack, key::String)
    for i in length(stack.layers):-1:1
        layer = stack.layers[i]
        if haskey(layer.data, key)
            value = layer.data[key]
            stack.effective[key] = value
            return value, true
        end
    end
    push!(stack.effective_missing, key)
    return nothing, false
end

function _settings_stack_get(stack::SettingsStack, key::String, default=nothing)
    _settings_stack_ensure_cache_epoch!(stack)
    if haskey(stack.effective, key)
        return stack.effective[key]
    end
    in(key, stack.effective_missing) && return default

    value, found = _settings_stack_resolve_and_cache!(stack, key)
    return found ? value : default
end

function _settings_stack_fill_all!(stack::SettingsStack)::SettingsStack
    _settings_stack_ensure_cache_epoch!(stack)
    stack.effective_complete && return stack
    merged = merge_settings((layer.data for layer in stack.layers)...)
    empty!(stack.effective)
    merge!(stack.effective, merged)
    stack.effective_complete = true
    return stack
end

function _settings_stack_keys(stack::SettingsStack)::Vector{String}
    _settings_stack_fill_all!(stack)
    return sort!(collect(keys(stack.effective)))
end

function _settings_stack_snapshot(stack::SettingsStack)::Dict{String, Any}
    _settings_stack_fill_all!(stack)
    return copy(stack.effective)
end


function _settings_builtin_layers(simos::SimOs)::Vector{SettingsLayer}
    layers = SettingsLayer[]

    # Layer 0: Defaults (lowest priority — process-wide fallback values)
    push!(layers, SettingsLayer(
        name = :defaults,
        kind = :defaults,
        origin = Dict{String, Any}(
            "source" => SETTINGS_SOURCE_TAG_DEFAULTS,
        ),
        data = _settings_flatten_dict(SIMULEOS_SETTINGS_DEFAULTS),
    ))

    # Layer 1: Home
    if !isnothing(simos.home)
        push!(layers, SettingsLayer(
            name = :home,
            kind = :home,
            persistent = true,
            origin = Dict{String, Any}(
                "path" => settings_path(simos.home),
            ),
            data = home_settings(simos.home),
        ))
    end

    # Layer 2: Project
    if !isnothing(simos.project)
        push!(layers, SettingsLayer(
            name = :project,
            kind = :project,
            persistent = true,
            origin = Dict{String, Any}(
                "path" => settings_path(simos.project),
            ),
            data = project_settings(simos.project),
        ))
    end

    # Layer 3: Environment
    push!(layers, SettingsLayer(
        name = :env,
        kind = :env,
        origin = Dict{String, Any}(
            "source" => SETTINGS_SOURCE_TAG_ENV,
        ),
        data = env_settings(),
    ))

    # Layer 4: Runtime
    push!(layers, SettingsLayer(
        name = :runtime,
        kind = :runtime,
        is_mutable = true,
        origin = Dict{String, Any}(
            "source" => SETTINGS_SOURCE_TAG_RUNTIME,
        ),
        data = _string_keys(simos.runtime_settings),
    ))

    # Layer 5: Script overlay (runtime mutable)
    push!(layers, SettingsLayer(
        name = :script,
        kind = :script,
        is_mutable = true,
        origin = Dict{String, Any}(
            "source" => SETTINGS_SOURCE_TAG_SCRIPT,
        ),
        data = Dict{String, Any}(),
    ))

    # Layer 6: Session overlay (runtime mutable, reset on session init/switch)
    push!(layers, SettingsLayer(
        name = :session,
        kind = :session,
        is_mutable = true,
        origin = Dict{String, Any}(
            "source" => SETTINGS_SOURCE_TAG_SESSION,
        ),
        data = Dict{String, Any}(),
    ))

    return layers
end

"""
    build_settings_stack(simos::SimOs) -> SettingsStack

Build the phase-1 settings stack from the current built-in sources.
Priority (low -> high): defaults, home, project, env, runtime, script, session.
Optional layers (:cli, :json_file) are inserted at runtime between existing layers.
"""
function build_settings_stack(simos::SimOs)::SettingsStack
    stack = SettingsStack(; layers = _settings_builtin_layers(simos))
    _settings_builtin_registry!(stack)
    _settings_stack_rebuild!(stack)
    return stack
end

"""
    load_settings_stack!(simos::SimOs) -> SettingsStack

Build and attach the settings stack to `simos`.
"""
function load_settings_stack!(simos::SimOs)::SettingsStack
    stack = build_settings_stack(simos)
    simos.settings_stack = stack
    return stack
end

function _settings_access_log!(simos::SimOs, key::String, value)::Nothing
    ws = simos.worksession
    isnothing(ws) && return nothing
    ws.settings_access_tracking || return nothing
    log = ws.settings_access_log
    isnothing(log) && return nothing
    log[key] = value
    return nothing
end

"""
    settings(simos::SimOs, key::String) -> value
    settings(simos::SimOs, key::String, default) -> value

Get a setting value by dotted key.
The single-key form errors if the key is missing.
"""
function settings(simos::SimOs, key::String, default)
    value = _settings_stack_get_resolved(_settings_stack_required(simos), key, default)
    _settings_access_log!(simos, key, value)
    return value
end

function settings(simos::SimOs, key::String)
    value = settings(simos, key, __MISSING__)
    value === __MISSING__ && error("Missing setting: $key")
    return value
end

function _settings_stack_required(simos::SimOs)::SettingsStack
    if isnothing(simos.settings_stack)
        return load_settings_stack!(simos)
    end
    return simos.settings_stack
end
