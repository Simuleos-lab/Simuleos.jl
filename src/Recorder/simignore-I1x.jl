"""
    set_simignore_rules!(recorder::Kernel.SessionRecorder, rules::Vector{Dict{Symbol, Any}})

I1x — writes `recorder.simignore_rules`

Set simignore rules for the given session recorder. Validates rules on set.

Each rule is a Dict with:
- `:regex` (required) - Regex pattern for matching variable names
- `:scope` (optional) - Scope label to target; if missing, rule applies to all scopes
- `:action` (required) - `:include` or `:exclude`

Variables are INCLUDED by default if no rules match.
Last matching rule determines the action.
"""
function set_simignore_rules!(
        recorder::Kernel.SessionRecorder,
        rules::Vector{T} where T<:RuleType
    )
    validated_rules = Dict{Symbol, Any}[]

    for rule in rules
        check_rules(rule)
        push!(validated_rules, rule)
    end

    recorder.simignore_rules = validated_rules
    return nothing
end

# I1x — writes `recorder.simignore_rules`
function append_simignore_rule!(
        recorder::Kernel.SessionRecorder, rule::RuleType
    )
    check_rules(rule)
    push!(recorder.simignore_rules, rule)
    return nothing
end

"""
    _should_ignore(recorder::Kernel.SessionRecorder, name::Symbol, val::Any, scope_label::String)::Bool

I1x — reads `recorder.simignore_rules`

Check if a variable should be ignored based on simignore rules.
Delegates to the pure `_should_ignore_var` in pipeline-I0x.jl.
"""
function _should_ignore(
        recorder::Kernel.SessionRecorder, name::Symbol,
        val::Any, scope_label::String
    )::Bool
    return _should_ignore_var(name, val, scope_label, recorder.simignore_rules)
end
