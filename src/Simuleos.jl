module Simuleos

using Dates
using SHA
using Serialization
using JSON3

# Include core modules
include("types.jl")
include("globals.jl")
include("lite.jl")
include("blob.jl")
include("git.jl")
include("metadata.jl")
include("json.jl")
include("tape.jl")
include("simignore.jl")
include("macros.jl")

# Include query module (order matters: handlers, wrappers, loaders)
include("query/handlers.jl")
include("query/wrappers.jl")
include("query/loaders.jl")

# Export macros
export @sim_session, @sim_store, @sim_context, @sim_capture, @sim_commit

# Export query API - Handlers
export RootHandler, SessionHandler, TapeHandler, BlobHandler
export sessions, tape, blob, exists

# Export query API - Wrappers
export CommitWrapper, ScopeWrapper, VariableWrapper, BlobWrapper
export session_label, commit_label, metadata, scopes, blob_refs
export label, timestamp, variables, labels, data
export name, src_type, value, blob_ref, src

# Export query API - Loaders
export iterate_raw_tape, iterate_tape, load_raw_blob, load_blob

end # module Simuleos
