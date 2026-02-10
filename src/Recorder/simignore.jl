# Simignore: variable filtering (like .gitignore for Simuleos)
# Rules are stored in SessionRecorder.simignore_rules
# I0x: check_rules, _rule_str | I1x: set_simignore_rules!, append_simignore_rule!, _should_ignore | I3x: simignore!

const RuleType = Dict{Symbol, T} where T

# Helper to stringify rule to a json-like string
function _rule_str(rule::RuleType)
    try
        return Kernel.JSON3.write(rule)
    catch
        return string(rule)
    end
end

function check_rules(rule::RuleType)
    # Validate :regex (required)
    if !haskey(rule, :regex)
        error("simignore rule missing required :regex field, rule $(_rule_str(rule))")
    end
    if !(rule[:regex] isa Regex)
        error("simignore rule :regex must be a Regex object, rule $(typeof(rule[:regex]))")
    end

    # Validate :action (required)
    if !haskey(rule, :action)
        error("simignore rule missing required :action field, rule $(_rule_str(rule))")
    end
    if rule[:action] != :include && rule[:action] != :exclude
        error("simignore rule :action must be :include or :exclude, rule $(_rule_str(rule))")
    end

    # Validate :scope (optional, must be string if present)
    if haskey(rule, :scope) && !(rule[:scope] isa AbstractString)
        error("simignore rule :scope must be a String, rule $(_rule_str(rule))")
    end
end

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

"""
    simignore!(rules::Vector)

I3x — via `_get_recorder()` → reads `SIMOS[].recorder`

Set simignore rules for the current session.
"""
function simignore!(rules::Vector{RuleType})
    recorder = _get_recorder()
    set_simignore_rules!(recorder, rules)
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
Delegates to the pure `_should_ignore_var` in pipeline.jl.
"""
function _should_ignore(
        recorder::Kernel.SessionRecorder, name::Symbol,
        val::Any, scope_label::String
    )::Bool
    return _should_ignore_var(name, val, scope_label, recorder.simignore_rules)
end
