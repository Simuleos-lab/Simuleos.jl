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

# Scoperias — Scope runtime types (needed by core types for CaptureContext)
include("scoperias/types-I0x.jl")

# Types first (no dependencies except home + scoperias types)
include("core/types.jl")

# Scoperias — Scope runtime operations
include("scoperias/ops-I0x.jl")
include("scoperias/macros-I0x.jl")

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
include("blobstorage/blob-I0x.jl")
include("blobstorage/blob-I2x.jl")
include("tapeio/json-I0x.jl")

# ScopeTapes low-level system (read + write)
include("scopetapes/handlers-I1x.jl")
include("scopetapes/read-I0x.jl")
include("scopetapes/read-I1x.jl")
include("scopetapes/write-I0x.jl")
include("scopetapes/write-I1x.jl")

# AGENT: IMPORTANT
# DO NOT ADD EXPORT STATEMENTS

end # module Kernel
