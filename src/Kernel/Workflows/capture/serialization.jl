# ============================================================
# capture/serialization.jl — Serialize PartialSnapshot subtypes
#
# Bridge between in-memory snapshot structs and Dict
# representations suitable for JSON/tape storage.
# ============================================================

"""
    serialize_capture(c::PartialSnapshot) -> Dict{String, Any}

Convert a PartialSnapshot to a Dict for JSON serialization.
"""
function serialize_capture(c::SettingsSnapshot)::Dict{String, Any}
    return Dict{String, Any}(
        "type" => "settings_capture",
        "accessed" => copy(c.accessed),
        "timestamp" => c.timestamp,
    )
end

function serialize_capture(c::SourceSnapshot)::Dict{String, Any}
    return Dict{String, Any}(
        "type" => "source_capture",
        "git_commit" => c.git_commit,
        "git_branch" => c.git_branch,
        "git_dirty" => c.git_dirty,
        "git_describe" => c.git_describe,
    )
end

function serialize_capture(c::EnvironmentSnapshot)::Dict{String, Any}
    return Dict{String, Any}(
        "type" => "environment_capture",
        "julia_version" => c.julia_version,
        "hostname" => c.hostname,
        "os" => c.os,
        "word_size" => c.word_size,
        "threads" => c.threads,
        "timestamp" => c.timestamp,
    )
end

function serialize_capture(c::ExecutionSnapshot)::Dict{String, Any}
    return Dict{String, Any}(
        "type" => "execution_capture",
        "src_file" => c.src_file,
        "src_line" => c.src_line,
        "threadid" => c.threadid,
        "timestamp" => c.timestamp,
    )
end

function serialize_capture(c::ScopeSnapshot)::Dict{String, Any}
    d = Dict{String, Any}(
        "type" => "scope_capture",
        "labels" => copy(c.labels),
        "variables" => Dict{String, Any}(string(k) => string(v) for (k, v) in c.variables),
    )
    if !isempty(c.metadata)
        d["metadata"] = Dict{String, Any}(string(k) => v for (k, v) in c.metadata)
    end
    return d
end

