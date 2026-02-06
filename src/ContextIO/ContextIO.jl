# ContextIO module - Session recording, scopes, tape, blobs, query
# Handles the context I/O system for simulation sessions

module ContextIO

import Dates
import SHA
import Serialization
import JSON3
import UXLayers

# Access sibling Core module
import ..Core

# Session management (must be first - other files depend on _get_session)
include("session.jl")

# Settings (UXLayers integration for Session)
include("settings.jl")

# Simignore (depends on session.jl for _get_session)
include("simignore.jl")

# Blob storage
include("blob.jl")

# JSON serialization
include("json.jl")

# Tape I/O
include("tape.jl")

# Scope processing (depends on blob.jl for _write_blob)
include("scope.jl")

# Query system
include("query/handlers.jl")
include("query/wrappers.jl")
include("query/loaders.jl")

# Macros (must be last - depends on everything else)
include("macros.jl")

# AGENT: IMPORTANT
# DO NOT ADD EXPORT STATEMENTS

end # module ContextIO
