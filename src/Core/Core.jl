# Core module - Types, git interface, shared utilities
# All other modules depend on Core

module Core

import Dates
import SHA
import Serialization
import UXLayers
import JSON3
import LibGit2

# Types first (no dependencies)
include("types.jl")

# Git interface
include("git.jl")

# Utilities
include("utils.jl")

include("UXLayer.jl")

# Settings (UXLayers integration)
include("settings.jl")

# OS global and operations
include("OS.jl")

# AGENT: IMPORTANT
# DO NOT ADD EXPORT STATEMENTS

end # module Core
