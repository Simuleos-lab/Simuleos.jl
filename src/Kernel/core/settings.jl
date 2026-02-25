# ============================================================
# settings.jl — Layered settings system
# ============================================================

const __MISSING__ = :__MISSING__

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

function _settings_registry_token(key::String)::String
    s = strip(key)
    isempty(s) && error("Settings registry key/alias token cannot be empty.")
    return s
end

function _settings_registry_find(stack::SettingsStack, key::String)::Union{Nothing, SettingsRegistryEntry}
    token = _settings_registry_token(key)
    if haskey(stack.registry, token)
        return stack.registry[token]
    end
    canonical = get(stack.registry_alias_to_canonical, token, nothing)
    isnothing(canonical) && return nothing
    return get(stack.registry, canonical, nothing)
end

function _settings_registry_aliases_resolve(entry::SettingsRegistryEntry)::Vector{String}
    aliases = String[]
    seen = Set{String}()
    # Canonical is always included for resolution, first.
    canon = _settings_registry_token(entry.canonical)
    push!(aliases, canon)
    push!(seen, canon)
    for alias in entry.aliases
        tok = _settings_registry_token(alias)
        tok in seen && continue
        push!(aliases, tok)
        push!(seen, tok)
    end
    return aliases
end

function _settings_registry_selector_layers(stack::SettingsStack, selector::Symbol)::Vector{SettingsLayer}
    if selector == :runtime
        out = SettingsLayer[]
        for name in (:session, :script, :bootstrap)
            layer = _settings_stack_layer(stack, name)
            isnothing(layer) || push!(out, layer)
        end
        return out
    elseif selector == :env
        layer = _settings_stack_layer(stack, :env)
        return isnothing(layer) ? SettingsLayer[] : SettingsLayer[layer]
    elseif selector == :project
        layer = _settings_stack_layer(stack, :project)
        return isnothing(layer) ? SettingsLayer[] : SettingsLayer[layer]
    elseif selector == :home
        layer = _settings_stack_layer(stack, :home)
        return isnothing(layer) ? SettingsLayer[] : SettingsLayer[layer]
    elseif selector == :file || selector == :json_file
        # Preserve current stack order among JSON-file layers; caller controls selector priority.
        return SettingsLayer[layer for layer in stack.layers if layer.kind == :json_file]
    else
        # Accept direct layer-name selectors.
        layer = _settings_stack_layer(stack, selector)
        return isnothing(layer) ? SettingsLayer[] : SettingsLayer[layer]
    end
end

function _settings_registry_resolve(
        stack::SettingsStack,
        entry::SettingsRegistryEntry,
    )::Tuple{Any, Bool, Union{Nothing, Symbol}, Union{Nothing, String}}
    aliases = _settings_registry_aliases_resolve(entry)
    priorities = entry.resolve_priority
    priorities isa Vector{Symbol} || error("Registry entry missing `resolve.priority` for custom resolve.")

    for selector in priorities
        layers = _settings_registry_selector_layers(stack, selector)
        for layer in layers
            for alias in aliases
                if haskey(layer.data, alias)
                    return layer.data[alias], true, layer.name, alias
                end
            end
        end
    end

    return nothing, false, nothing, nothing
end

function _settings_stack_get_resolved(stack::SettingsStack, key::String, default=nothing)
    requested = _settings_registry_token(key)
    entry = _settings_registry_find(stack, requested)
    if isnothing(entry)
        return _settings_stack_get(stack, requested, default)
    end

    if isnothing(entry.resolve_priority)
        # Registry hit, but no custom policy: map to canonical and delegate to default system.
        return _settings_stack_get(stack, entry.canonical, default)
    end

    value, found, _, _ = _settings_registry_resolve(stack, entry)
    return found ? value : default
end

function _settings_registry_normalize_priority(spec)::Union{Nothing, Vector{Symbol}}
    isnothing(spec) && return nothing
    spec isa AbstractVector || error("`resolve.priority` must be a vector of symbols/strings.")
    out = Symbol[]
    for item in spec
        if item isa Symbol
            push!(out, item)
        elseif item isa AbstractString
            s = strip(String(item))
            isempty(s) && error("`resolve.priority` entries cannot be empty.")
            push!(out, Symbol(s))
        else
            error("`resolve.priority` entries must be symbols/strings, got: $(typeof(item))")
        end
    end
    return out
end

function _settings_registry_spec_get(spec::AbstractDict, key::String, default=nothing)
    if haskey(spec, key)
        return spec[key]
    end
    sym = Symbol(key)
    if haskey(spec, sym)
        return spec[sym]
    end
    return default
end

function _settings_registry_entry_from_spec(
        canonical::String,
        spec::AbstractDict,
    )::SettingsRegistryEntry
    canonical_s = _settings_registry_token(canonical)
    aliases_raw = _settings_registry_spec_get(spec, "alias", String[])
    aliases_raw isa AbstractVector || error("Registry field `alias` must be a vector.")
    aliases = String[_settings_registry_token(string(a)) for a in aliases_raw]

    priority_raw = _settings_registry_spec_get(spec, "resolve.priority", nothing)
    if isnothing(priority_raw)
        resolve_obj = _settings_registry_spec_get(spec, "resolve", nothing)
        if resolve_obj isa AbstractDict
            priority_raw = _settings_registry_spec_get(resolve_obj, "priority", nothing)
        end
    end
    resolve_priority = _settings_registry_normalize_priority(priority_raw)

    return SettingsRegistryEntry(canonical_s, aliases, resolve_priority)
end

function _settings_registry_reindex_aliases!(stack::SettingsStack)::SettingsStack
    empty!(stack.registry_alias_to_canonical)
    for (canonical, entry) in stack.registry
        stack.registry_alias_to_canonical[_settings_registry_token(canonical)] = canonical
        for alias in entry.aliases
            stack.registry_alias_to_canonical[_settings_registry_token(alias)] = canonical
        end
    end
    return stack
end

function settings_registry_register!(
        simos::SimOs,
        canonical::String,
        spec::AbstractDict;
        replace::Bool = false,
    )::SettingsRegistryEntry
    stack = _settings_stack_required(simos)
    canonical_s = _settings_registry_token(canonical)
    haskey(stack.registry, canonical_s) && !replace &&
        error("Settings registry entry already exists for `$(canonical_s)`. Pass `replace=true` to replace it.")

    entry = _settings_registry_entry_from_spec(canonical_s, spec)
    stack.registry[canonical_s] = entry
    _settings_registry_reindex_aliases!(stack)
    _settings_stack_rebuild!(stack)  # registry changes can alter lookup results
    _settings_stack_sync_legacy!(simos)
    return entry
end

function settings_registry_unregister!(simos::SimOs, key_or_alias::String)::Bool
    stack = _settings_stack_required(simos)
    token = _settings_registry_token(key_or_alias)
    entry = _settings_registry_find(stack, token)
    isnothing(entry) && return false
    delete!(stack.registry, entry.canonical)
    _settings_registry_reindex_aliases!(stack)
    _settings_stack_rebuild!(stack)
    _settings_stack_sync_legacy!(simos)
    return true
end

function settings_registry_list(simos::SimOs)
    stack = _settings_stack_required(simos)
    out = NamedTuple[]
    for canonical in sort!(collect(keys(stack.registry)))
        entry = stack.registry[canonical]
        push!(out, (
            canonical = entry.canonical,
            aliases = copy(entry.aliases),
            resolve_priority = isnothing(entry.resolve_priority) ? nothing : copy(entry.resolve_priority),
        ))
    end
    return out
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
Priority (low -> high): home, project, env, bootstrap.
"""
function build_settings_stack(simos::SimOs)::SettingsStack
    stack = SettingsStack(; layers = _settings_builtin_layers(simos))
    _settings_stack_rebuild!(stack)
    return stack
end

"""
    load_settings_stack!(simos::SimOs) -> SettingsStack

Build and attach the settings stack to `simos`, and sync the legacy merged
settings cache (`simos.settings`) for compatibility.
"""
function load_settings_stack!(simos::SimOs)::SettingsStack
    stack = build_settings_stack(simos)
    simos.settings_stack = stack
    # Keep the legacy field alive for current callers/tests while stack is the SSOT.
    simos.settings = stack.effective
    return stack
end

"""
    load_all_settings(simos::SimOs) -> Dict{String, Any}

Compatibility wrapper: builds/attaches the settings stack and returns the
effective merged settings Dict.
"""
function load_all_settings(simos::SimOs)
    stack = load_settings_stack!(simos)
    _settings_stack_fill_all!(stack)
    return stack.effective
end

"""
    get_setting(simos::SimOs, key::String, default=nothing)

Get a setting value by dotted key.
"""
function get_setting(simos::SimOs, key::String, default=nothing)
    if !isnothing(simos.settings_stack)
        return _settings_stack_get_resolved(simos.settings_stack, key, default)
    end
    return get(simos.settings, key, default)
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

function _settings_stack_sync_legacy!(simos::SimOs)::SimOs
    stack = _settings_stack_required(simos)
    simos.settings = stack.effective
    return simos
end

function _settings_builtin_layer_name(name::Symbol)::Bool
    return name in (:home, :project, :env, :bootstrap, :script, :session)
end

function _settings_layer_info(layer::SettingsLayer, priority::Int)
    return (
        name = layer.name,
        kind = layer.kind,
        is_mutable = layer.is_mutable,
        persistent = layer.persistent,
        size = length(layer.data),
        priority = priority,
        origin = copy(layer.origin),
    )
end

function settings_source_list(simos::SimOs)
    stack = _settings_stack_required(simos)
    return [_settings_layer_info(layer, i) for (i, layer) in enumerate(stack.layers)]
end

function _settings_layer_required(stack::SettingsStack, name::Symbol)::SettingsLayer
    layer = _settings_stack_layer(stack, name)
    isnothing(layer) && error("Unknown settings layer: $(name)")
    return layer
end

function _settings_mutable_layer_required(stack::SettingsStack, name::Symbol)::SettingsLayer
    layer = _settings_layer_required(stack, name)
    layer.is_mutable || error("Settings layer `$(name)` is read-only.")
    return layer
end

function settings_layer_set!(
        simos::SimOs,
        layer_name::Symbol,
        key::String,
        value,
    )::Nothing
    stack = _settings_stack_required(simos)
    layer = _settings_mutable_layer_required(stack, layer_name)
    layer.data[_settings_validate_key(key)] = value
    _settings_stack_rebuild!(stack)
    _settings_stack_sync_legacy!(simos)
    return nothing
end

function settings_layer_unset!(
        simos::SimOs,
        layer_name::Symbol,
        key::String,
    )::Bool
    stack = _settings_stack_required(simos)
    layer = _settings_mutable_layer_required(stack, layer_name)
    removed = pop!(layer.data, _settings_validate_key(key), __MISSING__) !== __MISSING__
    removed && _settings_stack_rebuild!(stack)
    removed && _settings_stack_sync_legacy!(simos)
    return removed
end

function settings_layer_clear!(
        simos::SimOs,
        layer_name::Symbol;
        prefix = nothing,
    )::Int
    stack = _settings_stack_required(simos)
    layer = _settings_mutable_layer_required(stack, layer_name)

    removed = 0
    if isnothing(prefix)
        removed = length(layer.data)
        empty!(layer.data)
    else
        prefix_s = _settings_validate_key(string(prefix))
        doomed = String[]
        for k in keys(layer.data)
            startswith(k, prefix_s) || continue
            push!(doomed, k)
        end
        for k in doomed
            delete!(layer.data, k)
        end
        removed = length(doomed)
    end

    if removed > 0
        _settings_stack_rebuild!(stack)
        _settings_stack_sync_legacy!(simos)
    end
    return removed
end

function settings_layer_merge!(
        simos::SimOs,
        layer_name::Symbol,
        data::AbstractDict;
        clear::Bool = false,
    )::SettingsLayer
    stack = _settings_stack_required(simos)
    layer = _settings_mutable_layer_required(stack, layer_name)
    incoming = _settings_flatten_dict(data)
    clear && empty!(layer.data)
    merge!(layer.data, incoming)
    _settings_stack_rebuild!(stack)
    _settings_stack_sync_legacy!(simos)
    return layer
end

function _settings_require_layer_index(stack::SettingsStack, name::Symbol)::Int
    idx = _settings_stack_layer_index(stack, name)
    isnothing(idx) && error("Unknown settings layer: $(name)")
    return idx
end

function _settings_json_source_data(path::String; optional::Bool = false)::Dict{String, Any}
    abspath_path = abspath(path)
    if optional
        return _settings_flatten_dict(_read_json_file_or_empty(abspath_path))
    end
    return _settings_flatten_dict(_read_json_file(abspath_path))
end

function _settings_json_source_layer(
        path::String;
        name::Symbol,
        optional::Bool = false,
    )::SettingsLayer
    abs_path = abspath(path)
    data = _settings_json_source_data(abs_path; optional = optional)
    return SettingsLayer(
        name = name,
        kind = :json_file,
        is_mutable = false,
        persistent = false,
        origin = Dict{String, Any}(
            "path" => abs_path,
            "optional" => optional,
        ),
        data = data,
    )
end

function _settings_next_file_layer_name(stack::SettingsStack)::Symbol
    i = 1
    while true
        candidate = Symbol("file_", i)
        isnothing(_settings_stack_layer_index(stack, candidate)) && return candidate
        i += 1
    end
end

function _settings_insert_or_replace_layer!(
        stack::SettingsStack,
        layer::SettingsLayer;
        after::Union{Nothing, Symbol} = nothing,
        replace::Bool = false,
    )::SettingsLayer
    existing_idx = _settings_stack_layer_index(stack, layer.name)
    if !isnothing(existing_idx)
        replace || error("Settings layer `$(layer.name)` already exists. Pass `replace=true` to replace it.")
        old = stack.layers[existing_idx]
        if _settings_builtin_layer_name(old.name)
            error("Cannot replace builtin settings layer `$(old.name)`.")
        end
        stack.layers[existing_idx] = layer
        _settings_stack_rebuild!(stack)
        return layer
    end

    if isnothing(after)
        push!(stack.layers, layer)
    else
        anchor_idx = _settings_stack_layer_index(stack, after)
        isnothing(anchor_idx) && error("Unknown settings layer anchor `$(after)`.")
        insert!(stack.layers, anchor_idx + 1, layer)
    end
    _settings_stack_rebuild!(stack)
    return layer
end

function settings_source_add_json!(
        simos::SimOs,
        path::String;
        name = nothing,
        after::Symbol = :project,
        optional::Bool = false,
        replace::Bool = false,
    )::SettingsLayer
    stack = _settings_stack_required(simos)
    layer_name = if isnothing(name)
        _settings_next_file_layer_name(stack)
    elseif name isa Symbol
        name
    else
        Symbol(string(name))
    end
    _settings_builtin_layer_name(layer_name) &&
        error("Cannot register JSON source using reserved builtin layer name `$(layer_name)`.")

    layer = _settings_json_source_layer(path; name = layer_name, optional = optional)
    _settings_insert_or_replace_layer!(stack, layer; after = after, replace = replace)
    _settings_stack_sync_legacy!(simos)
    return layer
end

function settings_source_remove!(simos::SimOs, name::Symbol)::Nothing
    stack = _settings_stack_required(simos)
    idx = _settings_require_layer_index(stack, name)
    layer = stack.layers[idx]
    _settings_builtin_layer_name(layer.name) && error("Cannot remove builtin settings layer `$(name)`.")
    deleteat!(stack.layers, idx)
    _settings_stack_rebuild!(stack)
    _settings_stack_sync_legacy!(simos)
    return nothing
end

function _settings_reload_layer_data(layer::SettingsLayer)::Dict{String, Any}
    if layer.kind == :home || layer.kind == :project
        path = String(get(layer.origin, "path", ""))
        isempty(path) && error("Settings layer `$(layer.name)` missing reload path metadata.")
        return _read_json_file_or_empty(path)
    end
    if layer.kind == :json_file
        path = String(get(layer.origin, "path", ""))
        isempty(path) && error("Settings JSON layer `$(layer.name)` missing `path` metadata.")
        optional = get(layer.origin, "optional", false) === true
        return _settings_json_source_data(path; optional = optional)
    end
    if layer.kind == :env
        return env_settings()
    end
    if layer.kind == :bootstrap
        return layer.data
    end
    if layer.kind == :cli
        error("CLI settings source reload is not implemented yet.")
    end
    error("Unsupported settings layer kind for reload: $(layer.kind)")
end

function settings_source_reload!(simos::SimOs, name::Symbol)::SettingsLayer
    stack = _settings_stack_required(simos)
    idx = _settings_require_layer_index(stack, name)
    layer = stack.layers[idx]
    layer.data = _string_keys(_settings_reload_layer_data(layer))
    _settings_stack_rebuild!(stack)
    _settings_stack_sync_legacy!(simos)
    return layer
end

function settings_reload!(simos::SimOs)::SettingsStack
    stack = _settings_stack_required(simos)
    for layer in stack.layers
        if layer.kind in (:home, :project, :json_file, :env, :cli)
            layer.data = _string_keys(_settings_reload_layer_data(layer))
        end
    end
    _settings_stack_rebuild!(stack)
    _settings_stack_sync_legacy!(simos)
    return stack
end

function _settings_explain_candidates(stack::SettingsStack, key::String)
    candidates = NamedTuple[]
    for (i, layer) in enumerate(stack.layers)
        haskey(layer.data, key) || continue
        push!(candidates, (
            layer = layer.name,
            kind = layer.kind,
            priority = i,
            value = layer.data[key],
            origin = copy(layer.origin),
        ))
    end
    return candidates
end

function _settings_registry_explain_candidates(
        stack::SettingsStack,
        entry::SettingsRegistryEntry,
    )
    priorities = entry.resolve_priority
    priorities isa Vector{Symbol} || return NamedTuple[]

    aliases = _settings_registry_aliases_resolve(entry)
    candidates = NamedTuple[]
    for selector in priorities
        for layer in _settings_registry_selector_layers(stack, selector)
            priority_idx = _settings_require_layer_index(stack, layer.name)
            for alias in aliases
                haskey(layer.data, alias) || continue
                push!(candidates, (
                    layer = layer.name,
                    kind = layer.kind,
                    priority = priority_idx,
                    selector = selector,
                    alias = alias,
                    value = layer.data[alias],
                    origin = copy(layer.origin),
                ))
            end
        end
    end
    return candidates
end

function settings_explain(simos::SimOs, key::String; layer::Symbol = :effective)
    stack = _settings_stack_required(simos)
    requested_key = _settings_registry_token(key)

    if layer == :effective
        entry = _settings_registry_find(stack, requested_key)
        if !isnothing(entry)
            canonical_key = entry.canonical
            if !isnothing(entry.resolve_priority)
                candidates = _settings_registry_explain_candidates(stack, entry)
                if isempty(candidates)
                    return (
                        key = requested_key,
                        found = false,
                        layer = :effective,
                        winner_layer = nothing,
                        value = nothing,
                        candidates = candidates,
                        registry_hit = true,
                        canonical_key = canonical_key,
                        resolve_priority = copy(entry.resolve_priority),
                    )
                end
                winner = candidates[1]
                return (
                    key = requested_key,
                    found = true,
                    layer = :effective,
                    winner_layer = winner.layer,
                    value = winner.value,
                    candidates = candidates,
                    registry_hit = true,
                    canonical_key = canonical_key,
                    resolve_priority = copy(entry.resolve_priority),
                    matched_alias = winner.alias,
                )
            end

            # Registry hit with no custom policy: canonicalize key and use default explain path.
            candidates = _settings_explain_candidates(stack, canonical_key)
            if isempty(candidates)
                return (
                    key = requested_key,
                    found = false,
                    layer = :effective,
                    winner_layer = nothing,
                    value = nothing,
                    candidates = candidates,
                    registry_hit = true,
                    canonical_key = canonical_key,
                    resolve_priority = nothing,
                )
            end
            winner = candidates[end]
            return (
                key = requested_key,
                found = true,
                layer = :effective,
                winner_layer = winner.layer,
                value = winner.value,
                candidates = candidates,
                registry_hit = true,
                canonical_key = canonical_key,
                resolve_priority = nothing,
            )
        end

        key_norm = _settings_validate_key(requested_key)
        candidates = _settings_explain_candidates(stack, key_norm)
        if isempty(candidates)
            return (
                key = key_norm,
                found = false,
                layer = :effective,
                winner_layer = nothing,
                value = nothing,
                candidates = candidates,
                registry_hit = false,
            )
        end
        winner = candidates[end]
        return (
            key = key_norm,
            found = true,
            layer = :effective,
            winner_layer = winner.layer,
            value = winner.value,
            candidates = candidates,
            registry_hit = false,
        )
    end

    key_norm = _settings_validate_key(requested_key)
    layer_obj = _settings_stack_layer(stack, layer)
    isnothing(layer_obj) && error("Unknown settings layer: $(layer)")
    found = haskey(layer_obj.data, key_norm)
    candidates = found ? NamedTuple[(
        layer = layer_obj.name,
        kind = layer_obj.kind,
        priority = _settings_require_layer_index(stack, layer_obj.name),
        value = layer_obj.data[key_norm],
        origin = copy(layer_obj.origin),
    )] : NamedTuple[]
    return (
        key = key_norm,
        found = found,
        layer = layer,
        winner_layer = found ? layer : nothing,
        value = found ? layer_obj.data[key_norm] : nothing,
        candidates = candidates,
        registry_hit = false,
    )
end
