# ============================================================
# sources.jl — Settings layer mutation and source lifecycle
# ============================================================

# Protected layer names: builtins (:home, :project, :env, :runtime, :script, :session)
# plus :cli which is created on demand by settings_source_add_args! but should not be
# overwritten by JSON sources or removed once present.
function _settings_protected_layer_name(name::Symbol)::Bool
    return name in (:defaults, :home, :project, :env, :cli, :runtime, :script, :session)
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

function _settings_require_ready!(simos::SimOs, op_name::String)::Nothing
    simos.lifecycle === _SIMOS_LIFECYCLE_READY && return nothing
    error("$(op_name) requires initialized Simuleos engine. Call `sim_init!()` first.")
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
        value;
        source::String = SETTINGS_SOURCE_TAG_USER,
    )::Nothing
    stack = _settings_stack_required(simos)
    layer = _settings_mutable_layer_required(stack, layer_name)
    k = _settings_validate_key(key)
    layer.data[k] = value
    layer.key_origin[k] = source
    _settings_stack_rebuild!(stack)
    return nothing
end

function settings_layer_unset!(
        simos::SimOs,
        layer_name::Symbol,
        key::String,
    )::Bool
    stack = _settings_stack_required(simos)
    layer = _settings_mutable_layer_required(stack, layer_name)
    k = _settings_validate_key(key)
    removed = pop!(layer.data, k, __MISSING__) !== __MISSING__
    if removed
        delete!(layer.key_origin, k)
        _settings_stack_rebuild!(stack)
    end
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
        empty!(layer.key_origin)
    else
        prefix_s = _settings_validate_key(string(prefix))
        doomed = String[]
        for k in keys(layer.data)
            startswith(k, prefix_s) || continue
            push!(doomed, k)
        end
        for k in doomed
            delete!(layer.data, k)
            delete!(layer.key_origin, k)
        end
        removed = length(doomed)
    end

    if removed > 0
        _settings_stack_rebuild!(stack)
    end
    return removed
end

function settings_layer_merge!(
        simos::SimOs,
        layer_name::Symbol,
        data::AbstractDict;
        clear::Bool = false,
        source::String = SETTINGS_SOURCE_TAG_USER,
    )::SettingsLayer
    stack = _settings_stack_required(simos)
    layer = _settings_mutable_layer_required(stack, layer_name)
    incoming = _settings_flatten_dict(data)
    if clear
        empty!(layer.data)
        empty!(layer.key_origin)
    end
    merge!(layer.data, incoming)
    for k in keys(incoming)
        layer.key_origin[k] = source
    end
    _settings_stack_rebuild!(stack)
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
        if _settings_protected_layer_name(old.name)
            error("Cannot replace protected settings layer `$(old.name)`.")
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
    _settings_require_ready!(simos, "settings.source.add_json")
    stack = _settings_stack_required(simos)
    layer_name = if isnothing(name)
        _settings_next_file_layer_name(stack)
    elseif name isa Symbol
        name
    else
        _to_symbol_key(name)
    end
    _settings_protected_layer_name(layer_name) &&
        error("Cannot register JSON source using protected layer name `$(layer_name)`.")

    layer = _settings_json_source_layer(path; name = layer_name, optional = optional)
    _settings_insert_or_replace_layer!(stack, layer; after = after, replace = replace)
    return layer
end

function settings_source_remove!(simos::SimOs, name::Symbol)::Nothing
    _settings_require_ready!(simos, "settings.source.remove")
    stack = _settings_stack_required(simos)
    idx = _settings_require_layer_index(stack, name)
    layer = stack.layers[idx]
    _settings_protected_layer_name(layer.name) && error("Cannot remove protected settings layer `$(name)`.")
    deleteat!(stack.layers, idx)
    _settings_stack_rebuild!(stack)
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
    if layer.kind == :runtime
        return layer.data
    end
    if layer.kind == :cli
        error("CLI settings source reload is not implemented yet.")
    end
    error("Unsupported settings layer kind for reload: $(layer.kind)")
end

function _settings_reload_layer!(layer::SettingsLayer)::SettingsLayer
    layer.data = _string_keys(_settings_reload_layer_data(layer))
    layer.key_origin = Dict{String, String}()
    _settings_fill_key_origin!(layer)
    return layer
end

function settings_source_reload_external!(simos::SimOs, name::Symbol)::SettingsLayer
    _settings_require_ready!(simos, "settings.source.reload")
    stack = _settings_stack_required(simos)
    idx = _settings_require_layer_index(stack, name)
    layer = stack.layers[idx]
    _settings_reload_layer!(layer)
    _settings_stack_rebuild!(stack)
    return layer
end

function settings_reload_externals!(simos::SimOs)::SettingsStack
    _settings_require_ready!(simos, "settings.source.reload")
    stack = _settings_stack_required(simos)
    for layer in stack.layers
        if layer.kind in (:home, :project, :json_file, :env, :cli)  # :defaults is static, never reloaded
            _settings_reload_layer!(layer)
        end
    end
    _settings_stack_rebuild!(stack)
    return stack
end
