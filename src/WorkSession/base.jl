# ============================================================
# WorkSession/base.jl — Session construction and metadata
# ============================================================

"""
    _capture_session_metadata(; script_path="", extra...) -> Dict{String, Any}

Build session metadata dict with standard fields.
"""
function _session_metadata_base(; include_runtime::Bool = false, script_path::String = "")::Dict{String, Any}
    meta = Dict{String, Any}(
        _Kernel.SESSION_META_TIMESTAMP_KEY => string(Dates.now()),
    )

    if include_runtime
        meta[_Kernel.SESSION_META_JULIA_VERSION_KEY] = string(VERSION)
        meta[_Kernel.SESSION_META_HOSTNAME_KEY] = gethostname()
    end

    if !isempty(script_path)
        meta[_Kernel.SESSION_META_SCRIPT_PATH_KEY] = script_path
    end

    return meta
end

function _append_git_metadata!(meta::Dict{String, Any}, gh)::Dict{String, Any}
    isnothing(gh) && return meta

    h = _Kernel.git_hash(gh)
    !isempty(String(h)) && (meta[_Kernel.SESSION_META_GIT_COMMIT_KEY] = h)
    meta[_Kernel.SESSION_META_GIT_DIRTY_KEY] = _Kernel.git_dirty(gh)
    return meta
end

function _capture_session_metadata(; script_path::String = "", extra...)
    meta = _session_metadata_base(; include_runtime = true, script_path = script_path)

    sim = _Kernel._get_sim_or_nothing()
    gh = (!isnothing(sim) && !isnothing(sim.project)) ? sim.project.git_handler : nothing
    _append_git_metadata!(meta, gh)

    for (k, v) in extra
        meta[string(k)] = v
    end

    return meta
end

function _session_commit_metadata(gh)::Dict{String, Any}
    meta = _session_metadata_base()
    _append_git_metadata!(meta, gh)
    return meta
end
