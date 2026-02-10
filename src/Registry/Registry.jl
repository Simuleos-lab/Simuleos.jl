# Registry module - Home directory and project discovery
# Manages ~/.simuleos and cross-project references

module Registry

# Access sibling Kernel module
import ..Kernel

# Home directory management
include("home.jl")

# AGENT: IMPORTANT
# DO NOT ADD EXPORT STATEMENTS

end # module Registry
