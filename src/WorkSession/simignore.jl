# ============================================================
# WorkSession/simignore.jl — Filtering rules and registry
# ============================================================

const RuleType = Dict{Symbol, Any}

function _rule_str(rule::RuleType)
    scope = haskey(rule, :scope) ? " scope=$(rule[:scope])" : ""
    return "regex=$(rule[:regex]) action=$(rule[:action])$(scope)"
end

function _active_worksession()::_Kernel.WorkSession
    sim = _Kernel._get_sim()
    isnothing(sim.worksession) && error("No active session.")
    return sim.worksession
end

function _nonempty_string(value, what::AbstractString)::String
    value isa AbstractString || error("$(what) must be a string, got: $(typeof(value))")
    out = strip(String(value))
    isempty(out) && error("$(what) must be non-empty.")
    return out
end

function _copy_rule(rule::AbstractDict{Symbol, <:Any})::RuleType
    return Dict{Symbol, Any}(pairs(rule))
end

function _copy_rules(rules::AbstractVector{<:AbstractDict})::Vector{RuleType}
    return [_copy_rule(rule) for rule in rules]
end

function _copy_registered_filters(defs::Dict{String, Vector{RuleType}})
    out = Dict{String, Vector{RuleType}}()
    for (name, rules) in defs
        out[name] = _copy_rules(rules)
    end
    return out
end

function _copy_label_bindings(bindings::Dict{String, Vector{String}})
    out = Dict{String, Vector{String}}()
    for (label, names) in bindings
        out[label] = copy(names)
    end
    return out
end

function validate_rules(rule::AbstractDict{Symbol, <:Any}; allow_scope::Bool = true)
    haskey(rule, :regex) || error("Invalid simignore rule: missing :regex")
    rule[:regex] isa Regex || error("Invalid simignore rule: :regex must be Regex")

    haskey(rule, :action) || error("Invalid simignore rule: missing :action")
    rule[:action] in (:include, :exclude) || error("Invalid simignore rule: :action must be :include or :exclude")

    if haskey(rule, :scope)
        allow_scope || error("Invalid capture filter rule: :scope is not allowed in registered filters.")
        rule[:scope] isa AbstractString || error("Invalid simignore rule: :scope must be String")
    end
    return nothing
end

function _normalized_rules(rules::AbstractVector{<:AbstractDict}; allow_scope::Bool)::Vector{RuleType}
    out = RuleType[]
    for rule in rules
        validate_rules(rule; allow_scope=allow_scope)
        push!(out, _copy_rule(rule))
    end
    return out
end

function _push_unique!(xs::Vector{String}, x::String)
    x in xs && return xs
    push!(xs, x)
    return xs
end

function _normalize_filter_names(ws::_Kernel.WorkSession, filter_names::AbstractVector)::Vector{String}
    isempty(filter_names) && error("Capture filter list must be non-empty.")
    out = String[]
    for name in filter_names
        fname = _nonempty_string(name, "Capture filter name")
        haskey(ws.capture_filter_defs, fname) || error("Unknown capture filter: $(fname)")
        _push_unique!(out, fname)
    end
    return out
end

function _bind_filter_names!(ws::_Kernel.WorkSession, label_name::String, normalized_names::Vector{String})
    dest = get!(ws.capture_filter_bindings, label_name, String[])
    for fname in normalized_names
        _push_unique!(dest, fname)
    end
    return ws
end

function _resolve_capture_filter_names(ws::_Kernel.WorkSession, labels::AbstractVector{<:AbstractString})::Vector{String}
    out = String[]
    for label in labels
        names = get(ws.capture_filter_bindings, label, nothing)
        isnothing(names) && continue
        for fname in names
            _push_unique!(out, fname)
        end
    end
    return out
end

function _effective_scope_rules(ws::_Kernel.WorkSession, scope::_Kernel.SimuleosScope)::Vector{RuleType}
    rules = RuleType[]
    append!(rules, ws.simignore_rules)

    filter_names = _resolve_capture_filter_names(ws, scope.labels)
    for fname in filter_names
        append!(rules, ws.capture_filter_defs[fname])
    end

    return rules
end

function apply_capture_filters(scope::_Kernel.SimuleosScope, ws::_Kernel.WorkSession)::_Kernel.SimuleosScope
    rules = _effective_scope_rules(ws, scope)
    return _Kernel.filter_rules(scope, rules)
end

function set_simignore_rules!(ws::_Kernel.WorkSession, rules::AbstractVector{<:AbstractDict})
    empty!(ws.simignore_rules)
    append!(ws.simignore_rules, _normalized_rules(rules; allow_scope=true))
    return ws
end

function capture_filter_register!(ws::_Kernel.WorkSession, name::AbstractString, rules::AbstractVector{<:AbstractDict})
    fname = _nonempty_string(name, "Capture filter name")
    ws.capture_filter_defs[fname] = _normalized_rules(rules; allow_scope=false)
    return ws
end

function capture_filter_register!(name::AbstractString, rules::AbstractVector{<:AbstractDict})
    return capture_filter_register!(_active_worksession(), name, rules)
end

function capture_filter_register!(ws::_Kernel.WorkSession, defs::AbstractDict)
    for (name, rules) in defs
        rules isa AbstractVector || error("Capture filter `$(name)` rules must be a vector.")
        capture_filter_register!(ws, name, rules)
    end
    return ws
end

function capture_filter_register!(defs::AbstractDict)
    return capture_filter_register!(_active_worksession(), defs)
end

function capture_filter_bind!(ws::_Kernel.WorkSession, label::AbstractString, filter_names::AbstractVector)
    label_name = _nonempty_string(label, "Capture label")
    normalized_names = _normalize_filter_names(ws, filter_names)
    return _bind_filter_names!(ws, label_name, normalized_names)
end

function capture_filter_bind!(label::AbstractString, filter_names::AbstractVector)
    return capture_filter_bind!(_active_worksession(), label, filter_names)
end

function capture_filter_bind!(ws::_Kernel.WorkSession, binding::Pair)
    labels = binding.first
    filter_names = binding.second
    labels isa AbstractVector || error("Capture filter binding labels must be a vector.")
    filter_names isa AbstractVector || error("Capture filter binding filter names must be a vector.")
    isempty(labels) && error("Capture filter binding labels must be non-empty.")
    normalized_names = _normalize_filter_names(ws, filter_names)
    for label in labels
        _bind_filter_names!(ws, _nonempty_string(label, "Capture label"), normalized_names)
    end
    return ws
end

function capture_filter_bind!(binding::Pair)
    return capture_filter_bind!(_active_worksession(), binding)
end

function capture_filters_snapshot!(ws::_Kernel.WorkSession)
    return (
        global_rules = _copy_rules(ws.simignore_rules),
        filters = _copy_registered_filters(ws.capture_filter_defs),
        label_to_filters = _copy_label_bindings(ws.capture_filter_bindings),
    )
end

function capture_filters_snapshot!()
    return capture_filters_snapshot!(_active_worksession())
end

function capture_filters_reset!(ws::_Kernel.WorkSession)
    empty!(ws.simignore_rules)
    empty!(ws.capture_filter_defs)
    empty!(ws.capture_filter_bindings)
    return ws
end

function capture_filters_reset!()
    return capture_filters_reset!(_active_worksession())
end

function simignore!(rules::AbstractVector{<:AbstractDict})
    return set_simignore_rules!(_active_worksession(), rules)
end
