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

"""Check whether a scope DataClass has a variable with the given name."""
hasvar(scope::SnapScopeV1, name::Symbol) = haskey(scope.variables, name)
hasvar(scope::SnapSharedV1, name::Symbol) = haskey(scope.variables, name)

"""Extract scope snapshots from a capture commit or tree."""
commit_scope_snapshots(tree::CaptureTree)::Vector{SnapScopeV1} =
    SnapScopeV1[s for s in tree.snapshots if s isa SnapScopeV1]

commit_scope_snapshots(commit::RecCaptureCommitV1)::Vector{SnapScopeV1} =
    commit_scope_snapshots(commit.capture)

const LITE_TYPES = Union{Bool, Int, Float64, String, Nothing, Missing, Symbol}
_is_lite(::LITE_TYPES) = true
_is_lite(::Any) = false

const SETTING_KEY_HOME_PATH    = "home.path"
const SETTING_KEY_PROJECT_ROOT = "project.root"
const SETTING_KEY_SESSION_INIT_GIT_DIRTY_POLICY = "session.init.git_dirty_policy"
const SETTING_KEY_BATCH_COMMIT_MAX_PENDING = "worksession.batch_commit.max_pending_commits"
const SETTING_ALIAS_HOME_PATH_ENV = "SIMULEOS_HOME_PATH"
const SETTING_ALIAS_PROJECT_ROOT_ENV = "SIMULEOS_PROJECT_ROOT"

const SIMULEOS_SETTINGS_DEFAULTS = Dict{String, Any}(
    SETTING_KEY_SESSION_INIT_GIT_DIRTY_POLICY => "error",
    SETTING_KEY_BATCH_COMMIT_MAX_PENDING      => 10,
)

# -- Settings source tags (per-key origin tracking) --
const SETTINGS_SOURCE_TAG_DEFAULTS = "SIMULEOS_SETTINGS_DEFAULTS"
const SETTINGS_SOURCE_TAG_ENV      = "ENV"
const SETTINGS_SOURCE_TAG_RUNTIME  = "sim_init.runtime_settings"
const SETTINGS_SOURCE_TAG_SCRIPT   = "runtime.script.overlay"
const SETTINGS_SOURCE_TAG_SESSION  = "runtime.session.overlay"
const SETTINGS_SOURCE_TAG_CLI      = "cli_args"
const SETTINGS_SOURCE_TAG_USER     = "user"

# -- SimOs lifecycle states --
const _SIMOS_LIFECYCLE_BOOTSTRAP = :bootstrap
const _SIMOS_LIFECYCLE_READY     = :ready

const SESSION_META_TIMESTAMP_KEY = "timestamp"
const SESSION_META_JULIA_VERSION_KEY = "julia_version"
const SESSION_META_HOSTNAME_KEY = "hostname"
const SESSION_META_SCRIPT_PATH_KEY = "script_path"
const SESSION_META_INIT_FILE_KEY = "init_file"
const SESSION_META_INIT_LINE_KEY = "init_line"
const SESSION_META_GIT_COMMIT_KEY = "git_commit"
const SESSION_META_GIT_DIRTY_KEY = "git_dirty"
const CLASS_ID_KEY = "class_id"
const CLASS_VERSION_KEY = "class_version"

"""
    _record_field(data, key, default=nothing)

Read a record field by either string or symbol key.
"""
_record_field(data::AbstractDict, key::AbstractString, default=nothing) =
    haskey(data, key) ? data[key] : get(data, Symbol(key), default)

"""
    _record_class_id_value(data; default=nothing)

Return normalized `class_id` string (or `default` when missing).
"""
function _record_class_id_value(data::AbstractDict; default=nothing)
    raw = _record_field(data, CLASS_ID_KEY, default)
    isnothing(raw) && return default
    return string(raw)
end

"""
    _record_class_version_raw(data; default=nothing)

Return raw `class_version` field value (or `default` when missing).
"""
_record_class_version_raw(data::AbstractDict; default=nothing) =
    _record_field(data, CLASS_VERSION_KEY, default)

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
