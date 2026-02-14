# WorkSession module - Unified app-level session workflow owner
# Consumer of Kernel ScopeTapes low-level system

module WorkSession

import Dates
import ..Kernel

# Session management (must be first - other files depend on _get_worksession)
include("session-I0x.jl")
include("session-I3x.jl")

# Settings (UXLayers integration for WorkSession)
include("settings-I1x.jl")
include("settings-I3x.jl")

# Simignore
include("simignore-I0x.jl")
include("simignore-I1x.jl")
include("simignore-I3x.jl")

# Macros and function forms (must be last - depends on everything else)
include("macros-I0x.jl")
include("macros-I2x.jl")
include("macros-I3x.jl")

# AGENT: IMPORTANT
# DO NOT ADD EXPORT STATEMENTS

end # module WorkSession
