# Simignore: variable filtering (like .gitignore for Simuleos)
# Rules are stored in SessionRecorder.simignore_rules

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
