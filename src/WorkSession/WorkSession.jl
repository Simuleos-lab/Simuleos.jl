# ============================================================
# WorkSession.jl — Session recording module
#
# Manages work session lifecycle, simignore rules, and
# provides the user-facing macros for recording.
# ============================================================
module WorkSession

using UUIDs
using Dates

# Module-const references to avoid qualified paths in macros
import ..Kernel
const _Kernel = Kernel
const _WS = WorkSession

include("base.jl")
include("session.jl")
include("settings.jl")
include("simignore.jl")
include("macros.jl")
include("cache.jl")

end # module WorkSession
