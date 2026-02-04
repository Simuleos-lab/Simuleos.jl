# Traceability module - Context linking for artifacts
# "WTF made this plot?" - trace outputs back to their generation context

module Traceability

using Dates

using ..Core

# Context linking
include("context_links.jl")

# Exports
export link_artifact!, @trace_output
export query_context, query_context_by_path
export wtf

end # module Traceability
