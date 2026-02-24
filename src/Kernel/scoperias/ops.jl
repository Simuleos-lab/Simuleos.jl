# ============================================================
# scoperias/ops.jl — Scope operations: filtering, merging
# ============================================================

"""
    filter_rules(scope::SimuleosScope, rules::Vector{Dict{Symbol, Any}}) -> SimuleosScope

Apply filtering rules to a scope's variables.

Rules are processed in order; last matching rule wins.
Each rule: Dict(:regex => r"pattern", :action => :include/:exclude[, :scope => "label"])

Baseline behavior: Module and Function types are excluded unless an :include
rule matches (but include is still blocked for these types).
"""
function filter_rules(scope::SimuleosScope, rules::Vector{Dict{Symbol, Any}})
    filtered_vars = Dict{Symbol, ScopeVariable}()

    for (name, var) in scope.variables
        action = _resolve_action(name, var, scope, rules)
        if action != :exclude
            filtered_vars[name] = var
        end
    end

    return SimuleosScope(copy(scope.labels), filtered_vars, copy(scope.metadata))
end

function _resolve_action(name::Symbol, var::ScopeVariable, scope::SimuleosScope, rules)
    name_str = string(name)

    # Baseline: exclude Module and Function
    is_baseline_excluded = is_capture_excluded(var)
    action = is_baseline_excluded ? :exclude : :include

    for rule in rules
        # Check scope constraint
        if haskey(rule, :scope)
            rule_scope = string(rule[:scope])
            any(l -> l == rule_scope, scope.labels) || continue
        end

        # Check regex match
        regex = rule[:regex]
        occursin(regex, name_str) || continue

        # Baseline types cannot be force-included
        if is_baseline_excluded
            continue
        end

        action = rule[:action]
    end

    return action
end
