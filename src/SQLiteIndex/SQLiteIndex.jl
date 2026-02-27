module SQLiteIndex

import ..Kernel
import SQLite
import SHA
using Dates

const SQLITE_INDEX_SCHEMA_VERSION = 1
const SQLITE_INDEX_DIRNAME = "index"
const SQLITE_INDEX_FILENAME = "metadata-v1.sqlite"
const SQLITE_INDEX_KIND = "simuleos_metadata"
const _SQLITE_INDEX_SCOPE_SUBSYSTEM_ID = "scope"
const _SQLITE_INDEX_SCOPE_ADAPTER_VERSION = "phase4b.scope_adapter.v1"
const _SQLITE_INDEX_BLOB_SUBSYSTEM_ID = "blobstorage"
const _SQLITE_INDEX_BLOB_ADAPTER_VERSION = "phase4c.blob_adapter.v1"

include("sql_helpers.jl")
include("tape_index.jl")
include("session_index.jl")
include("Adapters/ScopeAdapter.jl")
include("Adapters/BlobAdapter.jl")
include("schema.jl")

"""
    sqlite_index_path(project_driver::Kernel.SimuleosProject) -> String

Canonical SQLite metadata-index path under the project's `.simuleos/` directory.
"""
sqlite_index_path(project_driver::Kernel.SimuleosProject)::String =
    joinpath(project_driver.simuleos_dir, SQLITE_INDEX_DIRNAME, SQLITE_INDEX_FILENAME)

sqlite_index_path(project_root::AbstractString)::String =
    sqlite_index_path(Kernel.resolve_project(String(project_root)))

"""
    sqlite_index_open(project_driver; create=false) -> SQLite.DB

Open the SQLite metadata index database for a project.
"""
function sqlite_index_open(project_driver::Kernel.SimuleosProject; create::Bool = false)
    path = sqlite_index_path(project_driver)
    if !create && !isfile(path)
        error("SQLite metadata index not found at `$(path)`. Run `sqlite_index_rebuild!(...)` first.")
    end
    Kernel.ensure_dir(dirname(path))
    db = SQLite.DB(path)
    _sqlite_exec(db, "PRAGMA foreign_keys = ON")
    return db
end

sqlite_index_open(project_root::AbstractString; create::Bool = false) =
    sqlite_index_open(Kernel.resolve_project(String(project_root)); create=create)

"""
    sqlite_index_rebuild!(project_driver; path=nothing) -> String

    Rebuild the SQLite metadata index from tapes/blobs metadata only.
Blob payloads are not deserialized.
Returns the SQLite database path.
"""
function sqlite_index_rebuild!(
        project_driver::Kernel.SimuleosProject;
        path::Union{Nothing, AbstractString} = nothing,
    )::String
    db_path = isnothing(path) ? sqlite_index_path(project_driver) : abspath(String(path))
    Kernel.ensure_dir(dirname(db_path))
    isfile(db_path) && rm(db_path; force=true)

    db = SQLite.DB(db_path)
    try
        _sqlite_exec(db, "PRAGMA foreign_keys = ON")
        _create_schema!(db)
        _with_sqlite_transaction(db) do
            _insert_manifest!(db, project_driver)
            _ensure_builtin_subsystems!(db)
            _index_registered_subsystems_rebuild!(db, project_driver)
            _recreate_public_views!(db)
            _touch_manifest_updated_at!(db)
        end
    finally
        SQLite.close(db)
    end

    return db_path
end

sqlite_index_rebuild!(project_root::AbstractString; kwargs...) =
    sqlite_index_rebuild!(Kernel.resolve_project(String(project_root)); kwargs...)

"""
    sqlite_index_refresh!(project_driver; path=nothing) -> String

Incrementally refresh the SQLite metadata index for append-only tape growth.
If drift is detected (tape rewrite/truncation or incompatible schema), falls back to
`sqlite_index_rebuild!`.
Returns the SQLite database path.
"""
function sqlite_index_refresh!(
        project_driver::Kernel.SimuleosProject;
        path::Union{Nothing, AbstractString} = nothing,
    )::String
    db_path = isnothing(path) ? sqlite_index_path(project_driver) : abspath(String(path))
    if !isfile(db_path)
        return sqlite_index_rebuild!(project_driver; path = db_path)
    end

    db = SQLite.DB(db_path)
    rebuild_needed = false
    try
        _sqlite_exec(db, "PRAGMA foreign_keys = ON")
        if !_is_refresh_capable_index_db(db, project_driver)
            rebuild_needed = true
        else
            try
                _with_sqlite_transaction(db) do
                    _ensure_builtin_subsystems!(db)
                    _refresh_registered_subsystems!(db, project_driver)
                    _recreate_public_views!(db)
                    _touch_manifest_updated_at!(db)
                end
            catch err
                if err isa _SQLiteIndexDriftError
                    rebuild_needed = true
                else
                    rethrow()
                end
            end
        end
    finally
        SQLite.close(db)
    end

    if rebuild_needed
        return sqlite_index_rebuild!(project_driver; path = db_path)
    end
    return db_path
end

sqlite_index_refresh!(project_root::AbstractString; kwargs...) =
    sqlite_index_refresh!(Kernel.resolve_project(String(project_root)); kwargs...)

end # module SQLiteIndex
