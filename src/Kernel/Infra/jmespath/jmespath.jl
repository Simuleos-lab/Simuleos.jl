# ============================================================
# jmespath/jmespath.jl — JMESPath query engine for Simuleos
#
# Minimal JMESPath subset:
#   - Field access: a.b.c, "quoted-field"
#   - Array index: [0], [-1]
#   - Wildcard: *, [*]
#   - Flatten: []
#   - Filter: [?predicate]
#   - Comparisons: == != < <= > >=
#   - Logical: && || !
#   - Literals: `42`, `"str"`, `true`, `null`
#   - Raw strings: 'hello'
#   - Projections (wildcard/flatten/filter + rhs)
#
# See: https://jmespath.org/specification.html
# ============================================================

include("types.jl")
include("tokenizer.jl")
include("parser.jl")
include("eval.jl")

"""
    jmespath_search(expression::AbstractString, data) → Any

Parse and evaluate a JMESPath expression against JSON-compatible data.
This is the main entry point.

# Examples
```julia
data = Dict("a" => Dict("b" => [1, 2, 3]))
jmespath_search("a.b[0]", data)   # → 1
jmespath_search("a.b[*]", data)   # → [1, 2, 3]

records = [Dict("name" => "x", "v" => 1), Dict("name" => "y", "v" => 2)]
jmespath_search("[?v > `1`].name", records)  # → ["y"]
```
"""
function jmespath_search(expression::AbstractString, data)
    expr = strip(expression)
    isempty(expr) && return data
    ast = _parse_jmespath(expr)
    return jmespath_eval(ast, data)
end
