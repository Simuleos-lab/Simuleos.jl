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
