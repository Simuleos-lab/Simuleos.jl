# Simuleos - An Operative System for Simulations
# Main module that wires up all subsystems

module Simuleos

# ==================================
# Core Module (must be first - all types defined here)
# ==================================
include("Core/Core.jl")

# ==================================
# App Modules (depend on Core)
# ==================================
include("ContextIO/ContextIO.jl")
include("FileSystem/FileSystem.jl")
include("Registry/Registry.jl")
include("Tools/Tools.jl")

# AGENT: IMPORTANT
# DO NOT ADD EXPORT STATEMENTS

end # module Simuleos
