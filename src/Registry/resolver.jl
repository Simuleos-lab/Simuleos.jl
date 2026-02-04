# Cross-project reference resolver
# Stub implementation - to be expanded

using ..Core: SimuleosHome, Project

"""
    register_project!(home::SimuleosHome, project::Project, name::String)

Register a project in the home registry under the given name.
"""
function register_project!(home::SimuleosHome, project::Project, name::String)
    # Stub implementation
    error("register_project! not yet implemented")
end

"""
    resolve_project(home::SimuleosHome, name::String)

Resolve a project name to its path using the registry.
Returns nothing if the project is not found.
"""
function resolve_project(home::SimuleosHome, name::String)::Union{Nothing, String}
    # Stub implementation
    error("resolve_project not yet implemented")
end

"""
    list_projects(home::SimuleosHome)

List all registered projects.
Returns a vector of (name, path) tuples.
"""
function list_projects(home::SimuleosHome)::Vector{Tuple{String, String}}
    # Stub implementation
    error("list_projects not yet implemented")
end

"""
    unregister_project!(home::SimuleosHome, name::String)

Remove a project from the registry.
"""
function unregister_project!(home::SimuleosHome, name::String)
    # Stub implementation
    error("unregister_project! not yet implemented")
end
