"""
    set_simignore_rules!(worksession::Kernel.WorkSession, rules::Vector{Dict{Symbol, Any}})

I1x — writes `worksession.simignore_rules`

Set simignore rules for the given work session. Validates rules on set.

Each rule is a Dict with:
- `:regex` (required) - Regex pattern for matching variable names
- `:scope` (optional) - Scope label to target; if missing, rule applies to all scopes
- `:action` (required) - `:include` or `:exclude`

Variables are INCLUDED by default if no rules match.
Last matching rule determines the action.
"""
function set_simignore_rules!(
        worksession::Kernel.WorkSession,
        rules::Vector{T} where T<:RuleType
    )
    validated_rules = Dict{Symbol, Any}[]

    for rule in rules
        validate_rules(rule)
        push!(validated_rules, rule)
    end

    worksession.simignore_rules = validated_rules
    return nothing
end

# I1x — writes `worksession.simignore_rules`
function append_simignore_rule!(
        worksession::Kernel.WorkSession, rule::RuleType
    )
    validate_rules(rule)
    push!(worksession.simignore_rules, rule)
    return nothing
end

"""
    _should_ignore(worksession::Kernel.WorkSession, name::Symbol, val::Any, scope_label::String)::Bool

I1x — reads `worksession.simignore_rules`

Check if a variable should be ignored based on simignore rules.
Delegates to the pure `Kernel._should_ignore_var` in Scoperias.
"""
function _should_ignore(
        worksession::Kernel.WorkSession, name::Symbol,
        val::Any, scope_label::String
    )::Bool
    return Kernel._should_ignore_var(name, val, scope_label, worksession.simignore_rules)
end
