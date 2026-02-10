# Recorder module - Session recording, macros, simignore
# Consumer of Kernel's data I/O layer

module Recorder

import Dates
import ..Kernel

# Session management (must be first - other files depend on _get_recorder)
include("session-I0x.jl")
include("session-I3x.jl")

# Settings (UXLayers integration for SessionRecorder)
include("settings-I1x.jl")
include("settings-I3x.jl")

# Simignore (depends on session-I3x.jl for _get_recorder)
include("simignore-I0x.jl")
include("simignore-I1x.jl")
include("simignore-I3x.jl")

# Pipeline primitives (object-level, no workflow globals)
include("pipeline-I0x.jl")
include("pipeline-I1x.jl")

# Macros (must be last - depends on everything else)
include("macros-I0x.jl")
include("macros-I3x.jl")

# AGENT: IMPORTANT
# DO NOT ADD EXPORT STATEMENTS

end # module Recorder
