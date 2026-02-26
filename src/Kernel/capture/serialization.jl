# ============================================================
# capture/serialization.jl — Serialize/deserialize PartialCapture
#
# Bridge between in-memory capture structs and Dict
# representations suitable for JSON/tape storage.
# ============================================================

"""
    serialize_capture(c::PartialCapture) -> Dict{String, Any}

Convert a PartialCapture to a Dict for JSON serialization.
"""
function serialize_capture(c::SettingsCapture)::Dict{String, Any}
    return Dict{String, Any}(
        "type" => "settings_capture",
        "accessed" => copy(c.accessed),
        "timestamp" => c.timestamp,
    )
end

function serialize_capture(c::SourceCapture)::Dict{String, Any}
    return Dict{String, Any}(
        "type" => "source_capture",
        "git_commit" => c.git_commit,
        "git_branch" => c.git_branch,
        "git_dirty" => c.git_dirty,
        "git_describe" => c.git_describe,
    )
end

function serialize_capture(c::EnvironmentCapture)::Dict{String, Any}
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

function serialize_capture(c::ExecutionCapture)::Dict{String, Any}
    return Dict{String, Any}(
        "type" => "execution_capture",
        "src_file" => c.src_file,
        "src_line" => c.src_line,
        "threadid" => c.threadid,
        "timestamp" => c.timestamp,
    )
end

