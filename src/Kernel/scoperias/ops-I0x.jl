# Scoperias — SimuleosScope runtime operations (all I0x — pure functions)
# Filter, merge, access — all operating on in-memory SimuleosScope objects.

# ==================================
# Variable access
# ==================================

getvariable(scope::SimuleosScope, name::Symbol) = scope.variables[name]
setvariable!(scope::SimuleosScope, name::Symbol, var::ScopeVariable) = (scope.variables[name] = var; scope)
variables(scope::SimuleosScope) = scope.variables

# ==================================
# Convenience
# ==================================

hasvar(scope::SimuleosScope, name::Symbol) = haskey(scope.variables, name)
Base.length(scope::SimuleosScope) = length(scope.variables)
Base.isempty(scope::SimuleosScope) = isempty(scope.variables)

# Iterate over (Symbol, ScopeVariable) pairs
Base.iterate(scope::SimuleosScope) = iterate(scope.variables)
Base.iterate(scope::SimuleosScope, state) = iterate(scope.variables, state)
Base.eltype(::Type{SimuleosScope}) = Pair{Symbol, ScopeVariable}

# ==================================
# Filter — variables
# ==================================

# Return new SimuleosScope with variables satisfying f(name, sv)
function filter_vars(f, scope::SimuleosScope)::SimuleosScope
    new_vars = Dict{Symbol, ScopeVariable}()
    for (name, sv) in scope.variables
        f(name, sv) && (new_vars[name] = sv)
    end
    SimuleosScope(copy(scope.labels), new_vars, copy(scope.metadata))
end

# Mutate in-place, remove variables where !f(name, sv)
function filter_vars!(f, scope::SimuleosScope)::SimuleosScope
    filter!(((name, sv),) -> f(name, sv), scope.variables)
    scope
end

# ==================================
# Filter — labels
# ==================================

# Return new SimuleosScope with labels satisfying f(label)
function filter_labels(f, scope::SimuleosScope)::SimuleosScope
    SimuleosScope(filter(f, scope.labels), copy(scope.variables), copy(scope.metadata))
end

# Mutate in-place, remove labels where !f(label)
function filter_labels!(f, scope::SimuleosScope)::SimuleosScope
    filter!(f, scope.labels)
    scope
end

# ==================================
# Merge — last-wins on variable collision, union of labels
# ==================================

function merge_scopes(scopes::SimuleosScope...)::SimuleosScope
    labels = String[]
    vars = Dict{Symbol, ScopeVariable}()
    data = Dict{Symbol, Any}()
    for scope in scopes
        for l in scope.labels
            l in labels || push!(labels, l)
        end
        merge!(vars, scope.variables)  # last-wins
        merge!(data, scope.metadata)  # last-wins
    end
    SimuleosScope(labels, vars, data)
end

# ==================================
# Rule filtering (simignore-style)
# ==================================

"""
    _should_ignore_var(name::Symbol, val::Any, scope_label::String, rules::Vector{Dict{Symbol, Any}})::Bool

Return whether a variable should be excluded by baseline filtering plus simignore rules.
- Baseline filtering always excludes `Module` and `Function` values.
- Rules use `:regex`, optional `:scope`, and `:action` (`:include`/`:exclude`).
- If multiple rules match, last match wins.
"""
function _should_ignore_var(
        name::Symbol,
        val::Any,
        scope_label::String,
        rules::Vector{Dict{Symbol, Any}}
    )::Bool
    val isa Module && return true
    val isa Function && return true

    name_str = string(name)
    last_action = nothing
    for rule in rules
        occursin(rule[:regex], name_str) || continue
        rule_scope = get(rule, :scope, nothing)
        isnothing(rule_scope) || rule_scope == scope_label || continue
        last_action = get(rule, :action, nothing)
    end

    return !isnothing(last_action) && last_action == :exclude
end

_scopevar_runtime_value(sv::InlineScopeVariable) = sv.value
_scopevar_runtime_value(::BlobScopeVariable) = nothing
_scopevar_runtime_value(::VoidScopeVariable) = nothing

"""
    filter_rules(scope::SimuleosScope, rules::Vector{Dict{Symbol, Any}})::SimuleosScope

Return a new scope filtered by simignore-style rules.
Baseline filtering always excludes `Module` and `Function` values.
Rules use `:regex`, optional `:scope`, and `:action` (`:include`/`:exclude`).
If multiple rules match, last match wins.
"""
function filter_rules(scope::SimuleosScope, rules::Vector{Dict{Symbol, Any}})::SimuleosScope
    primary_label = isempty(scope.labels) ? "" : scope.labels[1]

    return filter_vars(
        (name, sv) -> !_should_ignore_var(
            name, _scopevar_runtime_value(sv), primary_label, rules
        ),
        scope
    )
end

function _scopevar_mode(sv::ScopeVariable)::String
    if sv isa InlineScopeVariable
        return "inline"
    end
    if sv isa BlobScopeVariable
        return "blob"
    end
    return "void"
end

function _scopevar_preview(sv::ScopeVariable)::String
    if sv isa InlineScopeVariable
        text = repr(sv.value)
        return length(text) > 36 ? string(first(text, 33), "...") : text
    end
    if sv isa BlobScopeVariable
        return string("blob:", first(sv.blob_ref.hash, 10))
    end
    return "nothing"
end

function Base.show(io::IO, scope::SimuleosScope)
    print(io, "SimuleosScope(labels=", scope.labels, ", vars=", length(scope.variables), ")")
end

function Base.show(io::IO, ::MIME"text/plain", scope::SimuleosScope)
    println(io, "SimuleosScope")
    println(io, "  labels: ", scope.labels)
    println(io, "  metadata: ", isempty(scope.metadata) ? "empty" : collect(keys(scope.metadata)))
    println(io, "  variables (", length(scope.variables), "):")

    shown = 0
    for name in sort!(collect(keys(scope.variables)); by=string)
        sv = scope.variables[name]
        println(
            io,
            "    ",
            name,
            " [",
            sv.level,
            " ",
            sv.type_short,
            " ",
            _scopevar_mode(sv),
            "] = ",
            _scopevar_preview(sv)
        )
        shown += 1
        shown >= 10 && break
    end

    remaining = length(scope.variables) - shown
    remaining > 0 && println(io, "    ... +", remaining, " more")
end
