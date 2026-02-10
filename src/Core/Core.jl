# Core module - Types, git interface, shared utilities, data I/O, query system
# All other modules depend on Core

module Core

import Dates
import SHA
import Serialization
import UUIDs
import UXLayers
import JSON3
import LibGit2

# Home utilities (needed by types)
include("home.jl")

# Types first (no dependencies except home)
include("types.jl")

# Project structure: path helpers, project root discovery
include("project.jl")

# Git interface
include("git.jl")

# Utilities
include("utils.jl")

include("uxlayer.jl")

# SIMOS global and operations
include("SIMOS.jl")

# System init and validation (sim_init, validate_project_folder)
include("sys-init.jl")

# Settings
include("SIMOS-settings.jl")

# Data I/O primitives
include("blob.jl")
include("json.jl")

# Query system
include("query/handlers.jl")
include("query/loaders.jl")

# AGENT: IMPORTANT
# DO NOT ADD EXPORT STATEMENTS

end # module Core
