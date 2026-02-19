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
include("WorkSession/WorkSession.jl")
include("ScopeReader/ScopeReader.jl")
# include("Registry/Registry.jl")

# ==================================
# Public API
# ==================================
import .Kernel: sim_init!, sim_reset!
using .WorkSession: @session_init, @session_store, @scope_meta, @scope_capture, @session_commit
import .ScopeReader: project, each_scopes, value

# ==================================
# Exports
# ==================================
# AGENT: IMPORTANT
# PUT EXPORT STATEMENTS HERE

export sim_init!, sim_reset!
export project, each_scopes, value

# WorkSession macros (names kept stable for now)
export @session_init, @session_store, @scope_meta, @scope_capture, @session_commit

end # module Simuleos
