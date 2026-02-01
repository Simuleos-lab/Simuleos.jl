## -.--.-.-.- .. .. . . .- --- -- - -- -- .. 
# TODO/TAI: Make parametric type
struct ContextNode
    depot::Dict{String, Any}
end

ContextNode() = ContextNode(Dict())

# ## -.--.-.-.- .. .. . . .- --- -- - -- -- .. 
# # Container for a built in "flexible" quering interface
# # TODO/TAI: Make parametric type
# struct ContextQuery0
#     elms::Vector
# end

# ContextQuery0(v::Vector) = ContextQuery0(v)
# ContextQuery0(v) = ContextQuery0([v])

# macro q_str(s::String)
#     return _query_from_str_I(s)
# end

# function _query_from_str_I(s)
#     # TODO: Implement this
#     ContextQuery0([])
# end

## -.--.-.-.- .. .. . . .- --- -- - -- -- .. 
# Just a way to signal a quering failed
# Usage case: chain indexing or branching logic
struct MissingIndex end

const missidx = MissingIndex()

