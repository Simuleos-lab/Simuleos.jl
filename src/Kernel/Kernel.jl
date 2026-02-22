# ============================================================
# Kernel.jl — Core subsystem module
#
# All types, data I/O, scope management, and global state.
# No internal exports — everything accessed via Kernel.XXX
# ============================================================
module Kernel

using UUIDs
using Dates

# -- Core: types first, then utilities, then subsystems --
include("core/types.jl")
include("core/base.jl")
include("core/utils.jl")
include("core/fs.jl")
include("core/env.jl")

# -- Data subsystems (depend on types + utils) --
include("tapeio/json.jl")
include("tapeio/tape.jl")
include("blobstorage/blob.jl")
include("cache.jl")

# -- Scope subsystems --
include("scoperias/base.jl")
include("scoperias/ops.jl")
include("scoperias/macros.jl")
include("scopetapes/base.jl")
include("scopetapes/read.jl")
include("scopetapes/write.jl")

# -- Git --
include("gitmeta/git.jl")

# -- Project and Home (depend on fs, json) --
include("core/project.jl")
include("core/home.jl")

# -- Settings (depends on home, project, env) --
include("core/settings.jl")

# -- SimOs global state (depends on everything above) --
include("core/simos.jl")

end # module Kernel
