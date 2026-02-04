# Simignore: variable filtering (like .gitignore for Simuleos)
# Rules are stored in Session.simignore_rules
using ..Core: Session

const RuleType = Dict{Symbol, T} where T

# Helper to stringify rule to a json-like string
# - rg: for error messages
function _rule_str(rule::RuleType)
    try
        return JSON3.write(rule)  # Note: JSON3.write not JSON3.print for string output
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
    set_simignore_rules!(session::Session, rules::Vector{Dict{Symbol, Any}})

Set simignore rules for the given session. Validates rules on set.

Each rule is a Dict with:
- `:regex` (required) - Regex pattern for matching variable names
- `:scope` (optional) - Scope label to target; if missing, rule applies to all scopes
- `:action` (required) - `:include` or `:exclude`

Variables are INCLUDED by default if no rules match.
Last matching rule determines the action.
"""
function set_simignore_rules!(
        session::Session, 
        rules::Vector{T} where T<:RuleType
    )
    validated_rules = Dict{Symbol, Any}[]

    for rule in rules
        # Validate rule
        check_rules(rule)

        push!(validated_rules, rule)
    end

    session.simignore_rules = validated_rules
    return nothing
end

"""
    simignore!(rules::Vector)

Set simignore rules for the current session.

Example:
```julia
simignore!([
    Dict(:regex => r"^_", :action => :exclude),           # Exclude private vars
    Dict(:regex => r"^_temp_keep", :action => :include),  # But keep this one
    Dict(:regex => r"debug", :scope => "dev", :action => :exclude)  # Only in "dev" scope
])
```

"""
function simignore!(rules::Vector{RuleType})
    session = _get_session()
    set_simignore_rules!(session, rules)
end

function append_simignore_rule!(
        session::Session, rule::RuleType
    )
    check_rules(rule)
    push!(session.simignore_rules, rule)
    return nothing
end

"""
    _should_ignore(session::Session, name::Symbol, val::Any, scope_label::String)::Bool

Check if a variable should be ignored based on simignore rules.

Returns `true` if the variable should be ignored (not captured).

Logic:
1. Type-based filtering: Modules and Functions are always ignored
2. Rule-based filtering: Check simignore_rules
   - Find all rules where regex matches name AND (scope is missing OR scope == scope_label)
   - If no rules match: return false (include by default)
   - If rules match: return last matching rule's action == :exclude
"""
function _should_ignore(
        session::Session, name::Symbol, 
        val::Any, scope_label::String
    )::Bool
    # Step 1: Type-based filtering (always applied)
    val isa Module && return true
    val isa Function && return true
     
    # Step 2: Rule-based filtering
    name_str = string(name)
    last_rule = nothing
    for rule in session.simignore_rules
        # Check regex match
        regex_matches = occursin(rule[:regex], name_str)
        regex_matches || continue
            
        # Check scope match (if scope is specified)
        rule_scope = get(rule, :scope, nothing)
        isnothing(rule_scope) || rule_scope == scope_label || continue
        
        # Global rule (no scope specified)
        last_rule = rule
    end

    # No matching rules: include by default
    isnothing(last_rule) && return false

    # Last matching rule determines action
    last_action = get(last_rule, :action, nothing)
    return last_action == :exclude
end
