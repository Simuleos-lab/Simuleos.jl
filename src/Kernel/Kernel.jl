# ============================================================
# Kernel.jl — Core subsystem module
#
# All types, data I/O, scope management, and global state.
# No internal exports — everything accessed via Kernel.XXX
# ============================================================
module Kernel

using UUIDs
using Dates

# -- Core: snapshot types (no deps), then main types, then utilities --
include("core/snapshot_types.jl")
include("core/types.jl")
include("core/base.jl")
include("core/utils.jl")
include("core/fs.jl")
include("core/env.jl")

# -- Data subsystems (depend on types + utils) --
include("tapeio/json.jl")
include("tapeio/tape.jl")
include("tapeio/record.jl")
include("blobstorage/blob.jl")
include("cache.jl")

# -- Scope subsystems --
include("scoperias/base.jl")
include("scoperias/ops.jl")
include("scoperias/macros.jl")
include("scopetapes/base.jl")
include("scopetapes/write.jl")

# -- Git --
include("gitmeta/git.jl")

# -- Capture subsystem (collectors + serialization) --
include("capture/collectors.jl")
include("capture/serialization.jl")

# -- Project and Home (depend on fs, json) --
include("core/project.jl")
include("core/home.jl")

# -- Settings (depends on home, project, env) --
include("core/settings.jl")
include("core/cli_args.jl")

# -- SimOs global state (depends on everything above) --
include("core/simos.jl")

end # module Kernel
