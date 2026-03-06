# ============================================================
# Kernel.jl — Core subsystem module
#
# All types, data I/O, scope management, and global state.
# No internal exports — everything accessed via Kernel.XXX
# ============================================================
module Kernel

using UUIDs
using Dates

# -- Foundation primitives and shared state types --
include("Foundation/keys.jl")
include("Foundation/dataclass_types.jl")
include("Foundation/types.jl")
include("Foundation/utils.jl")
include("Foundation/state.jl")

# -- Infra (record-agnostic drivers + environment plumbing) --
include("Infra/project/fs.jl")
include("Infra/settings/env.jl")
include("Infra/tapeio/json.jl")
include("Infra/tapeio/tape.jl")
include("Infra/tapeio/record.jl")
include("Infra/blobstorage/blob.jl")
include("Infra/cache/cache.jl")

# -- Semantic class system --
include("ClassSystem/registry.jl")
include("ClassSystem/catalog.jl")
include("ClassSystem/tags.jl")
classsystem_bootstrap!()

# -- Semantic class implementation lanes (placeholder scaffolds) --
include("Classes/decode_dispatch.jl")
include("Classes/encode_dispatch.jl")
include("Classes/src/codebase.jl")
include("Classes/src/runtime_host.jl")
include("Classes/src/execution_site.jl")
include("Classes/src/settings_access.jl")
include("Classes/src/session_state.jl")
include("Classes/src/namespace_bindings.jl")
include("Classes/snap/scope.jl")
include("Classes/snap/context.jl")
include("Classes/snap/shared.jl")
include("Classes/rec/capture_commit.jl")
include("Classes/rec/ref.jl")

# -- Workflow: sessiontrace (formerly scope/scopetape flow) --
include("Workflows/sessiontrace/scoperias/base.jl")
include("Workflows/sessiontrace/scoperias/ops.jl")
include("Workflows/sessiontrace/scoperias/macros.jl")
include("Workflows/sessiontrace/scopetapes/base.jl")
include("Workflows/sessiontrace/scopetapes/read.jl")
include("Workflows/sessiontrace/scopetapes/write.jl")
include("Workflows/sessiontrace/reader.jl")

# -- Infra: git --
include("Infra/git/git.jl")

# -- Workflow: capture --
include("Workflows/capture/collectors.jl")
include("Workflows/capture/serialization.jl")

# -- Workflow placeholders for upcoming lane extraction --
include("Workflows/contextref/placeholder.jl")
include("Workflows/sharedstate/placeholder.jl")

# -- Infra: project/home/settings --
include("Infra/project/project.jl")
include("Infra/home/home.jl")
include("Infra/settings/settings.jl")
include("Infra/settings/cli_args.jl")

# -- SimOs global state (depends on everything above) --
include("Foundation/simos.jl")

end # module Kernel
