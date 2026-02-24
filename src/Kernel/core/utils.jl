# ============================================================
# utils.jl — Utility functions
# ============================================================

"""Truncate a type name to at most `n` characters."""
function type_short(T::Type, n::Int=50)
    s = string(T)
    length(s) <= n ? s : s[1:n-3] * "..."
end
type_short(x, n::Int=50) = type_short(typeof(x), n)
_type_short(x)::String = type_short(x, 25)

"""Baseline runtime-only values that should not be captured inline."""
is_capture_excluded(value)::Bool = value isa Module || value isa Function
function is_capture_excluded(var::ScopeVariable)::Bool
    var isa InlineScopeVariable || return false
    return is_capture_excluded(var.value)
end

"""Check whether a SimuleosScope has a variable with the given name."""
hasvar(scope::SimuleosScope, name::Symbol) = haskey(scope.variables, name)

const LITE_TYPES = Union{Bool, Int, Float64, String, Nothing, Missing, Symbol}
_is_lite(::LITE_TYPES) = true
_is_lite(::Any) = false

const SESSION_META_TIMESTAMP_KEY = "timestamp"
const SESSION_META_JULIA_VERSION_KEY = "julia_version"
const SESSION_META_HOSTNAME_KEY = "hostname"
const SESSION_META_SCRIPT_PATH_KEY = "script_path"
const SESSION_META_INIT_FILE_KEY = "init_file"
const SESSION_META_INIT_LINE_KEY = "init_line"
const SESSION_META_GIT_COMMIT_KEY = "git_commit"
const SESSION_META_GIT_DIRTY_KEY = "git_dirty"

"""
    _string_keys(d::AbstractDict)

Recursively convert all keys in a nested Dict to String.
"""
function _string_keys(d::AbstractDict)
    out = Dict{String, Any}()
    for (k, v) in d
        out[string(k)] = v isa AbstractDict ? _string_keys(v) : v
    end
    return out
end

