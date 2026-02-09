# Core utilities shared across modules
# Includes lite data detection and metadata capture

# ==================================
# Lite Data Detection and Conversion
# ==================================

const LITE_TYPES = Union{Bool,Int,Float64,String,Nothing,Missing,Symbol}

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
    _capture_session_metadata(script_path, git_handler=nothing)

Capture metadata for a session: timestamp, Julia version, hostname, git info.
"""
function _capture_session_metadata(
        script_path, 
        git_handler = Core.GitHandler(dirname(script_path))
    )::Dict{String,Any}
    meta = Dict{String,Any}()

    # Timestamp
    meta["timestamp"] = string(Dates.now())

    # Julia version
    meta["julia_version"] = string(VERSION)

    # Hostname
    meta["hostname"] = gethostname()

    # Script path
    meta["script_path"] = script_path

    # Git information
    if !isnothing(git_handler)
        try
            meta["git_commit"] = Core.git_hash(git_handler)
            meta["git_dirty"] = Core.git_dirty(git_handler)
        catch
            meta["git_commit"] = nothing
            meta["git_dirty"] = nothing
        end
    end

    return meta
end
