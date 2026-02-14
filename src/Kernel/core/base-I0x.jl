# Core base primitives (all I0x)
# Kept separate so `types-I0x.jl` remains type-only.

const TAPE_FILENAME = "context.tape.jsonl"
const BLOB_EXT = ".jls"

# Convenience constructor for callers that only pass repository path.
GitHandler(path::String) = GitHandler(path, nothing)

# Backward-compatible keyword constructors (formerly provided by @kwdef).
function SimOs(;
        home_path = default_home_path(),
        project_root = nothing,
        bootstrap = Dict{String, Any}(),
        project = nothing,
        _home = nothing,
        ux = nothing,
        worksession = nothing
    )
    return SimOs(home_path, project_root, bootstrap, project, _home, ux, worksession)
end

function Project(;
        id,
        root_path,
        simuleos_dir,
        blobstorage,
        git_handler = nothing
    )
    return Project(id, root_path, simuleos_dir, blobstorage, git_handler)
end

SimuleosHome(; path) = SimuleosHome(path)

function ContextLink(;
        artifact_hash,
        artifact_path = nothing,
        session_label,
        commit_label,
        timestamp
    )
    return ContextLink(artifact_hash, artifact_path, session_label, commit_label, timestamp)
end

_type_short(value)::String = first(string(typeof(value)), 25)
