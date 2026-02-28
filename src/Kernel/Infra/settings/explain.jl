# ============================================================
# explain.jl — Settings explain/report helpers
# ============================================================

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
