# Simuleos - An Operative System for Simulations
# Main module that wires up all subsystems

module Simuleos

# ==================================
# Kernel Module (must be first - all types defined here)
# ==================================
include("Kernel/Kernel.jl")

# ==================================
# App Modules (depend on Kernel)
# ==================================
include("Recorder/Recorder.jl")
include("Reader/Reader.jl")
include("Registry/Registry.jl")

# ==================================
# Bring macros into module scope
# ==================================
using .Recorder: @session_init, @session_store, @session_context, @session_capture, @session_commit

# ==================================
# Exports
# ==================================
# AGENT: IMPORTANT
# PUT EXPORT STATEMENTS HERE

# Recorder macros
export @session_init, @session_store, @session_context, @session_capture, @session_commit

# ==================================
# Auto-detection on load
# ==================================
function __init__()
    Kernel.sim_activate()
end

end # module Simuleos
