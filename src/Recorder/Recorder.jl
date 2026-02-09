# Recorder module - Session recording, macros, simignore
# Consumer of Core's data I/O layer

module Recorder

import Dates
import ..Core

# Session management (must be first - other files depend on _get_recorder)
include("session.jl")

# Settings (UXLayers integration for SessionRecorder)
include("settings.jl")

# Simignore (depends on session.jl for _get_recorder)
include("simignore.jl")

# Macros (must be last - depends on everything else)
include("macros.jl")

# AGENT: IMPORTANT
# DO NOT ADD EXPORT STATEMENTS

end # module Recorder
