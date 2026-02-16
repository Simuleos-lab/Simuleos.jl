# Simuleos - An Operative System for Simulations
# Main module that wires up all subsystems

module Simuleos

# ==================================
# Kernel Module (must be first - all types defined here)
# ==================================
include("Kernel/Kernel.jl")

# # ==================================
# # App Modules (depend on Kernel)
# # ==================================
# include("WorkSession/WorkSession.jl")
# include("Registry/Registry.jl")

# # ==================================
# # Bring macros into module scope
# # ==================================
# import .Kernel: sim_init, sim_activate
# using .WorkSession: @session_init, @session_store, @session_context, @session_capture, @session_commit

# # ==================================
# # Exports
# # ==================================
# # AGENT: IMPORTANT
# # PUT EXPORT STATEMENTS HERE

# # WorkSession macros (names kept stable for now)
# export sim_init, sim_activate
# export @session_init, @session_store, @session_context, @session_capture, @session_commit

# # ==================================
# # Auto-detection on load
# # ==================================
# function __init__()
#     if get(ENV, "SIMULEOS_TEST_MODE", "false") == "true"
#         @info "SIMULEOS_TEST_MODE detected in ENV - skipping auto-detection"
#     else
#         sim_activate()
#     end
# end

end # module Simuleos
