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

# Filesystem and home bootstrap utilities (needed by types)
include("core/fs-I0x.jl")
include("core/home-I0x.jl")

# Types first (all struct definitions are centralized here)
include("core/types-I0x.jl")
include("core/base-I0x.jl")

# # Scoperias — runtime constructors and operations
# include("scoperias/base-I0x.jl")

# include("scoperias/ops-I0x.jl")
# include("scoperias/macros-I0x.jl")

# Project structure: path helpers, project root discovery
include("core/project-I0x.jl")

# # Git interface
# include("gitmeta/git-I0x.jl")

# # Utilities
# include("core/utils-I0x.jl")

# # Core settings/loaders and validation
# include("core/uxlayer-I0x.jl")
# include("core/sys-init-I0x.jl")
# include("core/SIMOS-I0x.jl")

# Environment and UXLayer init (Phase 0)
include("core/env-I0x.jl")
include("core/uxlayer-init-I0x.jl")

# Core explicit-object APIs
include("core/project-I1x.jl")
include("core/home-I1x.jl")
# include("core/SIMOS-I2x.jl")
# include("core/project-I2x.jl")
# include("core/uxlayer-I2x.jl")
include("core/SIMOS-settings-I2x.jl")

# # Core global-state APIs
# include("core/SIMOS-I3x.jl")
include("core/sys-init-I3x.jl")

# # Data I/O primitives
# include("blobstorage/blob-I0x.jl")
# include("blobstorage/blob-I2x.jl")
# include("tapeio/json-I0x.jl")
# include("tapeio/tape-I0x.jl")

# # ScopeTapes low-level system (read + write)
# include("scopetapes/base-I0x.jl")
# include("scopetapes/read-I0x.jl")
# include("scopetapes/read-I1x.jl")
# include("scopetapes/write-I0x.jl")
# include("scopetapes/write-I1x.jl")

# AGENT: IMPORTANT
# DO NOT ADD EXPORT STATEMENTS

end # module Kernel
