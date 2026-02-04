# FileSystem module - File operations and project file management
# Handles file finding, project structure operations

module FileSystem

using ..Core

# File finder
include("finder.jl")

# Exports
export find_file, find_files, project_files

end # module FileSystem
