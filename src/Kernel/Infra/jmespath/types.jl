# ============================================================
# jmespath/types.jl — AST node types for JMESPath expressions
# ============================================================

abstract type JMESNode end

# --- Terminal nodes ---

"""Identity: the current node (implicit when no expression given)."""
struct JMESIdentity <: JMESNode end

"""Field access: `foo`, `"quoted-field"`."""
struct JMESField <: JMESNode
    name::String
end

"""Array index: `[0]`, `[-1]`."""
struct JMESIndex <: JMESNode
    index::Int  # 0-based per JMESPath spec
end

"""Literal value: `` `42` ``, `` `"hello"` ``, `` `true` ``."""
struct JMESLiteral <: JMESNode
    value::Any  # JSON-compatible value
end

"""Raw string: `'hello'`."""
struct JMESRawString <: JMESNode
    value::String
end

# --- Compound nodes ---

"""Sub-expression: `a.b` → SubExpr(Field("a"), Field("b"))."""
struct JMESSubExpr <: JMESNode
    left::JMESNode
    right::JMESNode
end

"""Index expression: `a[0]` → IndexExpr(Field("a"), Index(0))."""
struct JMESIndexExpr <: JMESNode
    left::JMESNode
    bracket::JMESNode  # JMESIndex, JMESFlatten, or JMESFilter
end

"""Wildcard: `*` — project all values of current object."""
struct JMESWildcard <: JMESNode end

"""Flatten: `[]` — flatten one level of nested arrays."""
struct JMESFlatten <: JMESNode end

"""List wildcard: `[*]` — project all elements of current array."""
struct JMESListWildcard <: JMESNode end

"""Filter expression: `[?expr]` — select array elements matching predicate."""
struct JMESFilter <: JMESNode
    predicate::JMESNode
end

"""Comparison: `a == b`, `a < b`, etc."""
struct JMESComparison <: JMESNode
    op::Symbol  # :eq, :ne, :lt, :le, :gt, :ge
    left::JMESNode
    right::JMESNode
end

"""Logical AND: `a && b`."""
struct JMESAnd <: JMESNode
    left::JMESNode
    right::JMESNode
end

"""Logical OR: `a || b`."""
struct JMESOr <: JMESNode
    left::JMESNode
    right::JMESNode
end

"""Logical NOT: `!a`."""
struct JMESNot <: JMESNode
    expr::JMESNode
end

"""Projection: wildcard/flatten/filter followed by remaining expression.
The projection evaluates `left` to get a collection, then maps `right` over each element."""
struct JMESProjection <: JMESNode
    left::JMESNode
    right::JMESNode
end
