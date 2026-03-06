# ============================================================
# jmespath/eval.jl — Evaluate JMESPath AST against data
#
# Data model: JSON-compatible Julia types
#   object  → Dict{String, Any} (or any AbstractDict)
#   array   → Vector{Any} (or any AbstractVector)
#   string  → String
#   number  → Int, Float64
#   boolean → Bool
#   null    → nothing
# ============================================================

"""
    jmespath_eval(node::JMESNode, data) → Any

Evaluate a JMESPath AST node against JSON-compatible data.
Returns `nothing` for missing/undefined paths (JMESPath null).
"""
function jmespath_eval end

function jmespath_eval(::JMESIdentity, data)
    return data
end

function jmespath_eval(node::JMESField, data)
    data isa AbstractDict || return nothing
    key = node.name
    haskey(data, key) && return data[key]
    # Try symbol key for Julia NamedTuples / symbol-keyed dicts
    sym = Symbol(key)
    haskey(data, sym) && return data[sym]
    return nothing
end

function jmespath_eval(node::JMESIndex, data)
    data isa AbstractVector || return nothing
    # JMESPath uses 0-based indexing; negative indices count from end
    idx = node.index
    n = length(data)
    julia_idx = idx >= 0 ? idx + 1 : n + idx + 1
    (1 <= julia_idx <= n) || return nothing
    return data[julia_idx]
end

function jmespath_eval(node::JMESLiteral, _data)
    return node.value
end

function jmespath_eval(node::JMESRawString, _data)
    return node.value
end

function jmespath_eval(node::JMESSubExpr, data)
    left_val = jmespath_eval(node.left, data)
    isnothing(left_val) && return nothing
    return jmespath_eval(node.right, left_val)
end

function jmespath_eval(node::JMESIndexExpr, data)
    left_val = jmespath_eval(node.left, data)
    isnothing(left_val) && return nothing
    return jmespath_eval(node.bracket, left_val)
end

# --- Wildcard: project all values of an object ---

function jmespath_eval(::JMESWildcard, data)
    data isa AbstractDict || return nothing
    return collect(values(data))
end

# --- List wildcard: project all elements of an array ---

function jmespath_eval(::JMESListWildcard, data)
    data isa AbstractVector || return nothing
    return data
end

# --- Flatten: flatten one level ---

function jmespath_eval(::JMESFlatten, data)
    data isa AbstractVector || return nothing
    result = Any[]
    for item in data
        if item isa AbstractVector
            append!(result, item)
        else
            push!(result, item)
        end
    end
    return result
end

# --- Filter: select elements matching predicate ---

function jmespath_eval(node::JMESFilter, data)
    data isa AbstractVector || return nothing
    result = Any[]
    for item in data
        val = jmespath_eval(node.predicate, item)
        _jmes_is_truthy(val) && push!(result, item)
    end
    return result
end

# --- Projection: map right expression over collection from left ---

function jmespath_eval(node::JMESProjection, data)
    left_val = jmespath_eval(node.left, data)
    (left_val isa AbstractVector) || return nothing
    result = Any[]
    for item in left_val
        val = jmespath_eval(node.right, item)
        # JMESPath projections suppress nulls
        isnothing(val) || push!(result, val)
    end
    return result
end

# --- Comparison ---

function jmespath_eval(node::JMESComparison, data)
    left_val = jmespath_eval(node.left, data)
    right_val = jmespath_eval(node.right, data)
    return _jmes_compare(node.op, left_val, right_val)
end

function _jmes_compare(op::Symbol, a, b)::Union{Bool, Nothing}
    # Equality works on any types
    op === :eq && return _jmes_equal(a, b)
    op === :ne && return !_jmes_equal(a, b)
    # Ordering only works on same-type numbers or strings
    _jmes_orderable(a, b) || return nothing
    op === :lt && return a < b
    op === :le && return a <= b
    op === :gt && return a > b
    op === :ge && return a >= b
    return nothing
end

function _jmes_equal(a, b)::Bool
    # null == null is true; null == anything else is false
    isnothing(a) && isnothing(b) && return true
    (isnothing(a) || isnothing(b)) && return false
    return a == b
end

function _jmes_orderable(a, b)::Bool
    (a isa Number && b isa Number) && return true
    (a isa AbstractString && b isa AbstractString) && return true
    return false
end

# --- Logical operators ---

function jmespath_eval(node::JMESAnd, data)
    left_val = jmespath_eval(node.left, data)
    _jmes_is_truthy(left_val) || return left_val
    return jmespath_eval(node.right, data)
end

function jmespath_eval(node::JMESOr, data)
    left_val = jmespath_eval(node.left, data)
    _jmes_is_truthy(left_val) && return left_val
    return jmespath_eval(node.right, data)
end

function jmespath_eval(node::JMESNot, data)
    val = jmespath_eval(node.expr, data)
    return !_jmes_is_truthy(val)
end

# --- Truthiness (JMESPath spec) ---

function _jmes_is_truthy(val)::Bool
    isnothing(val) && return false
    val isa Bool && return val
    val isa AbstractString && return !isempty(val)
    val isa AbstractVector && return !isempty(val)
    val isa AbstractDict && return !isempty(val)
    val isa Number && return true
    return true
end
