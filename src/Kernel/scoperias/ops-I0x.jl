# Scoperias — Scope runtime operations (all I0x — pure functions)
# Filter, merge, access — all operating on in-memory Scope objects.

# ==================================
# Variable access
# ==================================

getvariable(scope::Scope, name::Symbol) = scope.variables[name]
setvariable!(scope::Scope, name::Symbol, var::ScopeVariable) = (scope.variables[name] = var; scope)
variables(scope::Scope) = scope.variables

# ==================================
# Convenience
# ==================================

hasvar(scope::Scope, name::Symbol) = haskey(scope.variables, name)
Base.length(scope::Scope) = length(scope.variables)
Base.isempty(scope::Scope) = isempty(scope.variables)

# Iterate over (Symbol, ScopeVariable) pairs
Base.iterate(scope::Scope) = iterate(scope.variables)
Base.iterate(scope::Scope, state) = iterate(scope.variables, state)
Base.eltype(::Type{Scope}) = Pair{Symbol, ScopeVariable}

# ==================================
# Filter — variables
# ==================================

# Return new Scope with variables satisfying f(name, sv)
function filter_vars(f, scope::Scope)::Scope
    new_vars = Dict{Symbol, ScopeVariable}()
    for (name, sv) in scope.variables
        f(name, sv) && (new_vars[name] = sv)
    end
    Scope(copy(scope.labels), new_vars)
end

# Mutate in-place, remove variables where !f(name, sv)
function filter_vars!(f, scope::Scope)::Scope
    filter!(((name, sv),) -> f(name, sv), scope.variables)
    scope
end

# ==================================
# Filter — labels
# ==================================

# Return new Scope with labels satisfying f(label)
function filter_labels(f, scope::Scope)::Scope
    Scope(filter(f, scope.labels), copy(scope.variables))
end

# Mutate in-place, remove labels where !f(label)
function filter_labels!(f, scope::Scope)::Scope
    filter!(f, scope.labels)
    scope
end

# ==================================
# Merge — last-wins on variable collision, union of labels
# ==================================

function merge_scopes(scopes::Scope...)::Scope
    labels = String[]
    vars = Dict{Symbol, ScopeVariable}()
    for scope in scopes
        for l in scope.labels
            l in labels || push!(labels, l)
        end
        merge!(vars, scope.variables)  # last-wins
    end
    Scope(labels, vars)
end

# ==================================
# Rule filtering (simignore-style)
# ==================================

"""
    filter_rules(scope::Scope, rules::Vector{Dict{Symbol, Any}})::Scope

Return a new scope filtered by simignore-style rules.
Rules use `:regex`, optional `:scope`, and `:action` (`:include`/`:exclude`).
If multiple rules match, last match wins.
"""
function filter_rules(scope::Scope, rules::Vector{Dict{Symbol, Any}})::Scope
    primary_label = isempty(scope.labels) ? "" : scope.labels[1]

    return filter_vars((name, _sv) -> begin
        name_str = string(name)
        last_action = nothing
        for rule in rules
            occursin(rule[:regex], name_str) || continue
            rule_scope = get(rule, :scope, nothing)
            isnothing(rule_scope) || rule_scope == primary_label || continue
            last_action = get(rule, :action, nothing)
        end
        isnothing(last_action) ? true : last_action != :exclude
    end, scope)
end
