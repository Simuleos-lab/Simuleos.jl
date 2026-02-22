# ============================================================
# WorkSession/simignore.jl — Variable filtering rules
# ============================================================

const RuleType = Dict{Symbol, Any}

function _rule_str(rule::RuleType)
    scope = haskey(rule, :scope) ? " scope=$(rule[:scope])" : ""
    return "regex=$(rule[:regex]) action=$(rule[:action])$(scope)"
end

function validate_rules(rule::AbstractDict{Symbol, <:Any})
    haskey(rule, :regex) || error("Invalid simignore rule: missing :regex")
    rule[:regex] isa Regex || error("Invalid simignore rule: :regex must be Regex")

    haskey(rule, :action) || error("Invalid simignore rule: missing :action")
    rule[:action] in (:include, :exclude) || error("Invalid simignore rule: :action must be :include or :exclude")

    if haskey(rule, :scope)
        rule[:scope] isa AbstractString || error("Invalid simignore rule: :scope must be String")
    end
    return nothing
end

function set_simignore_rules!(ws::_Kernel.WorkSession, rules::AbstractVector{<:AbstractDict})
    empty!(ws.simignore_rules)
    for rule in rules
        validate_rules(rule)
        push!(ws.simignore_rules, Dict{Symbol, Any}(pairs(rule)))
    end
    return ws
end

function append_simignore_rule!(ws::_Kernel.WorkSession, rule::AbstractDict{Symbol, <:Any})
    validate_rules(rule)
    push!(ws.simignore_rules, Dict{Symbol, Any}(pairs(rule)))
    return ws
end

function _should_ignore(
        ws::_Kernel.WorkSession,
        name::Symbol,
        value,
        scope_label::AbstractString
    )::Bool
    # Baseline ignore for runtime-only entities.
    if _Kernel.is_capture_excluded(value)
        return true
    end

    action::Symbol = :include
    name_str = string(name)

    for rule in ws.simignore_rules
        haskey(rule, :scope) && string(rule[:scope]) != scope_label && continue
        occursin(rule[:regex], name_str) || continue
        action = rule[:action]
    end

    return action === :exclude
end

function simignore!(rules::AbstractVector{<:AbstractDict})
    sim = _Kernel._get_sim()
    isnothing(sim.worksession) && error("No active session.")
    return set_simignore_rules!(sim.worksession, rules)
end
