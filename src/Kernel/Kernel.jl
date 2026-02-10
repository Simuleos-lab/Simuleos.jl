# Kernel module - Types, git interface, shared utilities, data I/O, query system
# All other modules depend on Kernel

module Kernel

import Dates
import SHA
import Serialization
import UUIDs
import UXLayers
import JSON3
import LibGit2

# Home utilities (needed by types)
include("core/home.jl")

# Types first (no dependencies except home)
include("core/types.jl")

# Project structure: path helpers, project root discovery
include("core/project.jl")

# Git interface
include("gitmeta/git-I0x.jl")

# Utilities
include("core/utils.jl")

include("core/uxlayer.jl")

# SIMOS global and operations
include("core/SIMOS.jl")

# System init and validation (sim_init, validate_project_folder)
include("core/sys-init.jl")

# Settings
include("core/SIMOS-settings.jl")

# Data I/O primitives
include("blobstore/blob-I0x.jl")
include("tapeio/json-I0x.jl")

# Query system
include("querynav/loaders-I0x.jl")
include("querynav/handlers-I1x.jl")
include("querynav/loaders-I1x.jl")

# AGENT: IMPORTANT
# DO NOT ADD EXPORT STATEMENTS

end # module Kernel
