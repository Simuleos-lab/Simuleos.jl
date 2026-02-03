# Simignore: variable filtering (like .gitignore for Simuleos)
# Rules are stored in Session.simignore_rules

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
function set_simignore_rules!(session::Session, rules::Vector)
    validated_rules = Dict{Symbol, Any}[]

    for (i, rule) in enumerate(rules)
        # Convert to Dict{Symbol, Any} if needed
        rule_dict = Dict{Symbol, Any}(Symbol(k) => v for (k, v) in rule)

        # Validate :regex (required)
        if !haskey(rule_dict, :regex)
            error("simignore rule #$i: missing required :regex field")
        end
        if !(rule_dict[:regex] isa Regex)
            error("simignore rule #$i: :regex must be a Regex object, got $(typeof(rule_dict[:regex]))")
        end

        # Validate :action (required)
        if !haskey(rule_dict, :action)
            error("simignore rule #$i: missing required :action field")
        end
        if rule_dict[:action] != :include && rule_dict[:action] != :exclude
            error("simignore rule #$i: :action must be :include or :exclude, got $(rule_dict[:action])")
        end

        # Validate :scope (optional, must be string if present)
        if haskey(rule_dict, :scope) && !(rule_dict[:scope] isa AbstractString)
            error("simignore rule #$i: :scope must be a String, got $(typeof(rule_dict[:scope]))")
        end

        push!(validated_rules, rule_dict)
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
function simignore!(rules::Vector)
    session = _get_session()
    set_simignore_rules!(session, rules)
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
function _should_ignore(session::Session, name::Symbol, val::Any, scope_label::String)::Bool
    # Step 1: Type-based filtering (always applied)
    if val isa Module || val isa Function
        return true
    end

    # Step 2: Rule-based filtering
    name_str = string(name)
    matching_rules = filter(session.simignore_rules) do rule
        # Check regex match
        regex_matches = occursin(rule[:regex], name_str)
        if !regex_matches
            return false
        end

        # Check scope match (if scope is specified)
        if haskey(rule, :scope)
            return rule[:scope] == scope_label
        end

        return true  # Global rule (no scope specified)
    end

    # No matching rules: include by default
    if isempty(matching_rules)
        return false
    end

    # Last matching rule determines action
    last_action = matching_rules[end][:action]
    return last_action == :exclude
end
