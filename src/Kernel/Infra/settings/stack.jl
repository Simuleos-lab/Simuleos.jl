# ============================================================
# stack.jl — Core settings stack model and access API
# ============================================================

"""
    SettingsLayer(; name, kind, data=Dict(), is_mutable=false, persistent=false, origin=Dict())

Convenience constructor that normalizes metadata/data dictionaries to string keys.
"""
function SettingsLayer(;
        name::Symbol,
        kind::Symbol,
        data = Dict{String, Any}(),
        is_mutable::Bool = false,
        persistent::Bool = false,
        origin = Dict{String, Any}(),
    )
    data isa AbstractDict || error("SettingsLayer `data` must be a Dict-like object.")
    origin isa AbstractDict || error("SettingsLayer `origin` must be a Dict-like object.")
    return SettingsLayer(
        name,
        kind,
        is_mutable,
        persistent,
        _string_keys(origin),
        _string_keys(data),
    )
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

function _settings_flatten_into!(
        out::Dict{String, Any},
        data::AbstractDict,
        prefix::String = "",
    )::Dict{String, Any}
    for (k, v) in data
        key_seg = _settings_validate_key(string(k))
        full_key = isempty(prefix) ? key_seg : string(prefix, ".", key_seg)

        if v isa AbstractDict
            _settings_flatten_into!(out, _string_keys(v), full_key)
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
function _settings_flatten_dict(data::AbstractDict)::Dict{String, Any}
    out = Dict{String, Any}()
    _settings_flatten_into!(out, _string_keys(data))
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
        key = _settings_validate_key(string(k))
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
            "prefix" => ENV_PREFIX,
        ),
        data = env_settings(),
    ))

    # Layer 4: Bootstrap
    push!(layers, SettingsLayer(
        name = :bootstrap,
        kind = :bootstrap,
        is_mutable = true,
        origin = Dict{String, Any}(
            "source" => "sim_init.bootstrap",
        ),
        data = _string_keys(simos.bootstrap),
    ))

    # Layer 5: Script overlay (runtime mutable)
    push!(layers, SettingsLayer(
        name = :script,
        kind = :script,
        is_mutable = true,
        origin = Dict{String, Any}(
            "source" => "runtime.script.overlay",
        ),
        data = Dict{String, Any}(),
    ))

    # Layer 6: Session overlay (runtime mutable, reset on session init/switch)
    push!(layers, SettingsLayer(
        name = :session,
        kind = :session,
        is_mutable = true,
        origin = Dict{String, Any}(
            "source" => "runtime.session.overlay",
        ),
        data = Dict{String, Any}(),
    ))

    return layers
end

"""
    build_settings_stack(simos::SimOs) -> SettingsStack

Build the phase-1 settings stack from the current built-in sources.
Priority (low -> high): home, project, env, bootstrap, script, session.
Optional layers (:cli, :json_file) are inserted at runtime between existing layers.
"""
function build_settings_stack(simos::SimOs)::SettingsStack
    stack = SettingsStack(; layers = _settings_builtin_layers(simos))
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

"""
    get_setting(simos::SimOs, key::String, default=nothing)

Get a setting value by dotted key.
"""
function get_setting(simos::SimOs, key::String, default=nothing)
    value = _settings_stack_get_resolved(_settings_stack_required(simos), key, default)
    _settings_access_log!(simos, key, value)
    return value
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

function _require_setting(key::String, value)
    value === __MISSING__ && error("Missing setting: $key")
    return value
end

settings(simos::SimOs, key::String) = _require_setting(key, get_setting(simos, key, __MISSING__))
settings(simos::SimOs, key::String, default) = get_setting(simos, key, default)

function _settings_stack_required(simos::SimOs)::SettingsStack
    if isnothing(simos.settings_stack)
        return load_settings_stack!(simos)
    end
    return simos.settings_stack
end
