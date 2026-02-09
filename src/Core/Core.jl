# Core module - Types, git interface, shared utilities, data I/O, query system
# All other modules depend on Core

module Core

import Dates
import SHA
import Serialization
import UXLayers
import JSON3
import LibGit2

# Home utilities (needed by types)
include("home.jl")

# Types first (no dependencies except home)
include("types.jl")

# Git interface
include("git.jl")

# Utilities
include("utils.jl")

include("UXLayer.jl")

# OS global and operations
include("OS.jl")

# Settings (UXLayers integration)
include("OS-settings.jl")

# Data I/O (moved from ContextIO)
include("blob.jl")
include("json.jl")
include("tape.jl")
include("scope.jl")

# Query system (moved from ContextIO)
include("query/handlers.jl")
include("query/loaders.jl")

# AGENT: IMPORTANT
# DO NOT ADD EXPORT STATEMENTS

end # module Core
