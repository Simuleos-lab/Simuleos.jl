# Registry module - Home directory and project discovery
# Manages ~/.simuleos and cross-project references

module Registry

using ..Core

# Home directory management
include("home.jl")

# Project resolver
include("resolver.jl")

# Exports
export init_home, home_path, registry_path, config_path
export register_project!, resolve_project, list_projects, unregister_project!

end # module Registry
