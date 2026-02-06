# Core utilities shared across modules
# Includes lite data detection and metadata capture

using Dates

# ==================================
# Lite Data Detection and Conversion
# ==================================

const LITE_TYPES = Union{Bool, Int, Float64, String, Nothing, Missing, Symbol}

_is_lite(::LITE_TYPES) = true
_is_lite(::Any) = false

function _liteify(value::Bool)
    return value
end

function _liteify(value::Int)
    return value
end

function _liteify(value::Float64)
    return value
end

function _liteify(value::String)
    return value
end

function _liteify(::Nothing)
    return nothing
end

function _liteify(::Missing)
    return "__missing__"
end

function _liteify(value::Symbol)
    return string(value)
end

function _liteify(value::Any)
    error("Cannot liteify non-lite value of type $(typeof(value))")
end

# ==================================
# Metadata Capture
# ==================================

"""
    _capture_metadata(script_path, git_handler=nothing)

Capture metadata for a session: timestamp, Julia version, hostname, git info.
"""
function _capture_metadata(script_path, git_handler=nothing)::Dict{String, Any}
    meta = Dict{String, Any}()

    # Timestamp
    meta["timestamp"] = string(now())

    # Julia version
    meta["julia_version"] = string(VERSION)

    # Hostname
    meta["hostname"] = gethostname()

    # Script path
    meta["script_path"] = script_path

    # Git information
    if isnothing(git_handler)
        script_dir = dirname(script_path)
        if isempty(script_dir)
            script_dir = pwd()
        end

        # Try to get git information using GitHandler
        try
            gh = GitHandler(script_dir)
            meta["git_commit"] = git_hash(gh)
            meta["git_dirty"] = git_dirty(gh)
        catch
            meta["git_commit"] = nothing
            meta["git_dirty"] = nothing
        end
    else
        try
            meta["git_commit"] = git_hash(git_handler)
            meta["git_dirty"] = git_dirty(git_handler)
        catch
            meta["git_commit"] = nothing
            meta["git_dirty"] = nothing
        end
    end

    return meta
end
