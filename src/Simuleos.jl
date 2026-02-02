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
include("metadata.jl")
include("json.jl")
include("tape.jl")
include("simignore.jl")
include("macros.jl")

# Export macros
export @sim_session, @sim_store, @sim_context, @sim_capture, @sim_commit

end # module Simuleos
