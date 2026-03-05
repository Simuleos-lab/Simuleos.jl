# ============================================================
# registry.jl — Settings registry canonical/alias resolution
# ============================================================

function _settings_registry_token(key::String)::String
    s = strip(key)
    isempty(s) && error("Settings registry key/alias token cannot be empty.")
    return s
end

# Derive the Julia-identifier-compatible alias for a canonical key: "a.b.c" -> "a_b_c".
function _settings_julia_alias(canonical::String)::String
    return replace(canonical, "." => "_")
end

# Derive the fully-dotted alias for a canonical key: "a.b.c_d" -> "a.b.c.d".
# This is the form produced by `_runtime_settings_from_pairs` which replaces all "_" with ".".
function _settings_dotted_alias(canonical::String)::String
    return replace(canonical, "_" => ".")
end

# Return the full alias list, prepending auto-generated aliases (Julia-id and fully-dotted)
# when they differ from the canonical key.
function _settings_aliases_with_julia_id(canonical::String, explicit::Vector{String})::Vector{String}
    auto = String[]
    for alias in (_settings_julia_alias(canonical), _settings_dotted_alias(canonical))
        alias == canonical && continue
        alias in explicit && continue
        alias in auto && continue
        push!(auto, alias)
    end
    return vcat(auto, explicit)
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
        for name in (:session, :script, :runtime)
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
        # Registry hit, but no custom policy: search canonical + all aliases in default stack order.
        # Must interleave alias checks per-layer so a higher-priority layer with an alias
        # wins over a lower-priority layer with the canonical key.
        _settings_stack_ensure_cache_epoch!(stack)
        all_keys = vcat([entry.canonical], entry.aliases)
        for i in length(stack.layers):-1:1
            layer = stack.layers[i]
            for k in all_keys
                if haskey(layer.data, k)
                    value = layer.data[k]
                    # Cache under canonical key for consistency with the effective cache contract.
                    stack.effective[entry.canonical] = value
                    return value
                end
            end
        end
        return default
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

    return SettingsRegistryEntry(canonical_s, _settings_aliases_with_julia_id(canonical_s, aliases), resolve_priority)
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
    return true
end

function _settings_registry_register_entry!(stack::SettingsStack, canonical::String, aliases::Vector{String})
    stack.registry[canonical] = SettingsRegistryEntry(canonical, _settings_aliases_with_julia_id(canonical, aliases), nothing)
end

function _settings_builtin_registry!(stack::SettingsStack)
    _settings_registry_register_entry!(stack, SETTING_KEY_HOME_PATH,
        [SETTING_ALIAS_HOME_PATH_ENV])
    _settings_registry_register_entry!(stack, SETTING_KEY_PROJECT_ROOT,
        [SETTING_ALIAS_PROJECT_ROOT_ENV])
    _settings_registry_register_entry!(stack, SETTING_KEY_SESSION_INIT_GIT_DIRTY_POLICY,
        String[])
    _settings_registry_register_entry!(stack, SETTING_KEY_BATCH_COMMIT_MAX_PENDING,
        String[])
    _settings_registry_reindex_aliases!(stack)
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
