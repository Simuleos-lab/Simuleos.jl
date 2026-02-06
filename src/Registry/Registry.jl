# Registry module - Home directory and project discovery
# Manages ~/.simuleos and cross-project references

module Registry

using ..Core

# Home directory management
include("home.jl")

# Exports
export init_home, home_path, registry_path, config_path

end # module Registry
