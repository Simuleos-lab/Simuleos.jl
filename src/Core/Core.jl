# Core module - Types, git interface, shared utilities
# All other modules depend on Core

module Core

using Dates
using SHA
using Serialization
using UXLayers

# Types first (no dependencies)
include("types.jl")

# Git interface
include("git.jl")

# Utilities
include("utils.jl")

# Settings (UXLayers integration)
include("settings.jl")

# Export types
export SimOS, Project
export Session, Stage, Scope, ScopeVariable
export GitHandler
export SimuleosHome, ContextLink

# Export git functions
export git_hash, git_dirty, git_describe, git_branch, git_remote, git_init
export _verify_repo

# Export utilities
export LITE_TYPES, _is_lite, _liteify
export _capture_metadata

# Export settings functions
export settings, ux_root, __MISSING__, _resolve_setting

end # module Core
