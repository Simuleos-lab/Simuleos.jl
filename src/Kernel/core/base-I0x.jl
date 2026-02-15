# Core base primitives (all I0x)
# Kept separate so `types-I0x.jl` remains type-only.

const TAPE_FILENAME = "context.tape.jsonl"
const BLOB_EXT = ".jls"

# Convenience constructor for callers that only pass repository path.
GitHandler(path::String) = GitHandler(path, nothing)

function SimOs(;
        bootstrap = Dict{String, Any}(),
        project = nothing,
        home = nothing,
        ux = nothing,
        worksession = nothing
    )
    return SimOs(bootstrap, project, home, ux, worksession)
end

function SimuleosProject(;
        root_path,
        id = nothing,
        simuleos_dir = _simuleos_dir(root_path),
        blobstorage = BlobStorage(simuleos_dir),
        git_handler = nothing
    )
    return SimuleosProject(id, root_path, simuleos_dir, blobstorage, git_handler)
end

SimuleosHome(; path) = SimuleosHome(path)


_type_short(value)::String = first(string(typeof(value)), 25)
