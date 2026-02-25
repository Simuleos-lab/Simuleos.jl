module SQLiteIndex

import ..Kernel
import SQLite
using Dates

const SQLITE_INDEX_SCHEMA_VERSION = 1
const SQLITE_INDEX_DIRNAME = "index"
const SQLITE_INDEX_FILENAME = "metadata-v1.sqlite"

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

Rebuild the Phase-1 SQLite metadata index from tapes/blobs metadata only.
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
            _index_project_sessions!(db, project_driver; refresh_mode = "rebuild")
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
                    _refresh_project_sessions!(db, project_driver)
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

# ------------------------------------------------------------
# SQLite helpers
# ------------------------------------------------------------

_sqlite_exec(db::SQLite.DB, sql::AbstractString) = (SQLite.DBInterface.execute(db, String(sql)); nothing)
_sqlite_exec(db::SQLite.DB, sql::AbstractString, params) = (SQLite.DBInterface.execute(db, String(sql), params); nothing)

struct _SQLiteIndexDriftError <: Exception
    message::String
end
Base.showerror(io::IO, err::_SQLiteIndexDriftError) = print(io, err.message)

function _with_sqlite_transaction(f::Function, db::SQLite.DB)
    _sqlite_exec(db, "BEGIN IMMEDIATE")
    try
        f()
        _sqlite_exec(db, "COMMIT")
    catch
        try
            _sqlite_exec(db, "ROLLBACK")
        catch
        end
        rethrow()
    end
    return nothing
end

# ------------------------------------------------------------
# Schema
# ------------------------------------------------------------

function _create_schema!(db::SQLite.DB)
    _sqlite_exec(db, """
        CREATE TABLE index_manifest (
            manifest_id INTEGER PRIMARY KEY CHECK (manifest_id = 1),
            schema_version INTEGER NOT NULL,
            index_kind TEXT NOT NULL,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            project_root TEXT NOT NULL,
            simuleos_dir TEXT NOT NULL,
            builder_version TEXT NOT NULL
        )
    """)

    _sqlite_exec(db, """
        CREATE TABLE sessions (
            session_id TEXT PRIMARY KEY,
            session_label TEXT,
            session_json_path TEXT NOT NULL,
            session_init_file TEXT,
            session_init_line INTEGER,
            session_timestamp TEXT,
            session_git_commit TEXT,
            session_git_dirty INTEGER
        )
    """)
    _sqlite_exec(db, "CREATE INDEX idx_sessions_session_label ON sessions(session_label)")

    _sqlite_exec(db, """
        CREATE TABLE session_labels (
            session_id TEXT NOT NULL,
            label_ord INTEGER NOT NULL,
            label TEXT NOT NULL,
            PRIMARY KEY (session_id, label_ord),
            FOREIGN KEY(session_id) REFERENCES sessions(session_id) ON DELETE CASCADE
        )
    """)
    _sqlite_exec(db, "CREATE INDEX idx_session_labels_label ON session_labels(label)")

    _sqlite_exec(db, """
        CREATE TABLE session_index_state (
            session_id TEXT PRIMARY KEY,
            session_label TEXT,
            last_indexed_commit_ord INTEGER NOT NULL,
            last_indexed_tape_record_ord INTEGER NOT NULL,
            last_tape_file TEXT,
            last_tape_line_no INTEGER,
            last_refresh_at TEXT NOT NULL,
            refresh_mode TEXT NOT NULL,
            FOREIGN KEY(session_id) REFERENCES sessions(session_id) ON DELETE CASCADE
        )
    """)

    _sqlite_exec(db, """
        CREATE TABLE commits (
            commit_uid TEXT PRIMARY KEY,
            session_id TEXT NOT NULL,
            commit_ord INTEGER NOT NULL,
            commit_label TEXT NOT NULL,
            commit_timestamp TEXT,
            tape_record_ord INTEGER NOT NULL,
            tape_file TEXT NOT NULL,
            tape_line_no INTEGER NOT NULL,
            UNIQUE(session_id, commit_ord),
            UNIQUE(session_id, tape_record_ord),
            FOREIGN KEY(session_id) REFERENCES sessions(session_id) ON DELETE CASCADE
        )
    """)
    _sqlite_exec(db, "CREATE INDEX idx_commits_session_id ON commits(session_id)")
    _sqlite_exec(db, "CREATE INDEX idx_commits_commit_label ON commits(commit_label)")

    _sqlite_exec(db, """
        CREATE TABLE scopes (
            scope_uid TEXT PRIMARY KEY,
            commit_uid TEXT NOT NULL,
            session_id TEXT NOT NULL,
            commit_ord INTEGER NOT NULL,
            scope_ord INTEGER NOT NULL,
            src_file TEXT,
            src_line INTEGER,
            threadid INTEGER,
            UNIQUE(commit_uid, scope_ord),
            FOREIGN KEY(commit_uid) REFERENCES commits(commit_uid) ON DELETE CASCADE,
            FOREIGN KEY(session_id) REFERENCES sessions(session_id) ON DELETE CASCADE
        )
    """)
    _sqlite_exec(db, "CREATE INDEX idx_scopes_session_id ON scopes(session_id)")
    _sqlite_exec(db, "CREATE INDEX idx_scopes_src_file ON scopes(src_file)")

    _sqlite_exec(db, """
        CREATE TABLE scope_labels (
            scope_uid TEXT NOT NULL,
            label_ord INTEGER NOT NULL,
            label TEXT NOT NULL,
            PRIMARY KEY (scope_uid, label_ord),
            FOREIGN KEY(scope_uid) REFERENCES scopes(scope_uid) ON DELETE CASCADE
        )
    """)
    _sqlite_exec(db, "CREATE INDEX idx_scope_labels_label ON scope_labels(label)")

    _sqlite_exec(db, """
        CREATE TABLE scope_vars (
            scope_uid TEXT NOT NULL,
            var_name TEXT NOT NULL,
            var_ord INTEGER NOT NULL,
            storage_kind TEXT NOT NULL,
            scope_level TEXT,
            type_short TEXT,
            blob_ref TEXT,
            hash_ref TEXT,
            PRIMARY KEY (scope_uid, var_name),
            FOREIGN KEY(scope_uid) REFERENCES scopes(scope_uid) ON DELETE CASCADE
        )
    """)
    _sqlite_exec(db, "CREATE INDEX idx_scope_vars_var_name ON scope_vars(var_name)")
    _sqlite_exec(db, "CREATE INDEX idx_scope_vars_blob_ref ON scope_vars(blob_ref)")

    _sqlite_exec(db, """
        CREATE TABLE scope_meta_kv (
            scope_uid TEXT NOT NULL,
            meta_key TEXT NOT NULL,
            value_kind TEXT NOT NULL,
            value_text TEXT,
            PRIMARY KEY (scope_uid, meta_key),
            FOREIGN KEY(scope_uid) REFERENCES scopes(scope_uid) ON DELETE CASCADE
        )
    """)
    _sqlite_exec(db, "CREATE INDEX idx_scope_meta_kv_meta_key ON scope_meta_kv(meta_key)")

    return nothing
end

function _insert_manifest!(db::SQLite.DB, project_driver::Kernel.SimuleosProject)
    now_s = string(Dates.now())
    _sqlite_exec(db, """
        INSERT INTO index_manifest (
            manifest_id, schema_version, index_kind, created_at, updated_at,
            project_root, simuleos_dir, builder_version
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    """, (
        1,
        SQLITE_INDEX_SCHEMA_VERSION,
        "simuleos_metadata",
        now_s,
        now_s,
        project_driver.root_path,
        project_driver.simuleos_dir,
        string("phase2"),
    ))
    return nothing
end

function _touch_manifest_updated_at!(db::SQLite.DB)
    _sqlite_exec(db,
        "UPDATE index_manifest SET updated_at = ? WHERE manifest_id = 1",
        (string(Dates.now()),),
    )
    return nothing
end

# ------------------------------------------------------------
# Rebuild scan
# ------------------------------------------------------------

function _index_project_sessions!(db::SQLite.DB, project_driver::Kernel.SimuleosProject; refresh_mode::String)
    sdir = Kernel.sessions_dir(project_driver.simuleos_dir)
    isdir(sdir) || return nothing

    for entry in sort!(readdir(sdir))
        sjson = Kernel.session_json_path(project_driver, entry)
        isfile(sjson) || continue
        raw = Kernel._read_json_file(sjson)
        _index_session!(db, project_driver, raw, sjson; refresh_mode = refresh_mode)
    end
    return nothing
end

function _index_session!(
        db::SQLite.DB,
        project_driver::Kernel.SimuleosProject,
        raw::Dict{String, Any},
        sjson::String;
        refresh_mode::String,
    )
    session_id = string(get(raw, Kernel.SESSION_FILE_ID_KEY, ""))
    isempty(session_id) && error("Invalid session.json at `$(sjson)`: missing session_id.")

    labels = Kernel._session_labels(raw)
    primary_label = isempty(labels) ? nothing : labels[1]
    meta = Kernel._session_meta(raw)

    _sqlite_exec(db, """
        INSERT INTO sessions (
            session_id, session_label, session_json_path, session_init_file, session_init_line,
            session_timestamp, session_git_commit, session_git_dirty
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    """, (
        session_id,
        primary_label,
        sjson,
        _string_or_nothing(get(meta, Kernel.SESSION_META_INIT_FILE_KEY, nothing)),
        _int_or_nothing(get(meta, Kernel.SESSION_META_INIT_LINE_KEY, nothing)),
        _string_or_nothing(get(meta, Kernel.SESSION_META_TIMESTAMP_KEY, nothing)),
        _string_or_nothing(get(meta, Kernel.SESSION_META_GIT_COMMIT_KEY, nothing)),
        _bool_int_or_nothing(get(meta, Kernel.SESSION_META_GIT_DIRTY_KEY, nothing)),
    ))

    for (label_ord, label) in enumerate(labels)
        _sqlite_exec(db,
            "INSERT INTO session_labels (session_id, label_ord, label) VALUES (?, ?, ?)",
            (session_id, label_ord, label),
        )
    end

    stats = _index_session_tape!(db, project_driver, session_id)
    _update_session_index_state!(db, session_id, primary_label, stats; refresh_mode = refresh_mode)
    return nothing
end

function _index_session_tape!(db::SQLite.DB, project_driver::Kernel.SimuleosProject, session_id::String)
    tape = Kernel.TapeIO(Kernel.tape_path(project_driver.simuleos_dir, session_id))

    ctx_file = Ref("")
    ctx_line = Ref(0)

    records = Kernel.each_tape_records_filtered(
        tape;
        line_filter = (line, ctx) -> true,
        json_filter = (obj, ctx) -> begin
            ctx_file[] = ctx.file
            ctx_line[] = ctx.line_no
            true
        end,
    )

    tape_record_ord = 0
    commit_ord = 0
    last_commit_file = nothing
    last_commit_line = nothing

    for raw in records
        tape_record_ord += 1
        _record_type(raw) == "commit" || continue

        commit_ord += 1
        commit = Kernel._parse_commit(raw)
        commit_uid = _commit_uid(session_id, commit_ord)

        _sqlite_exec(db, """
            INSERT INTO commits (
                commit_uid, session_id, commit_ord, commit_label, commit_timestamp,
                tape_record_ord, tape_file, tape_line_no
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            commit_uid,
            session_id,
            commit_ord,
            commit.commit_label,
            _string_or_nothing(get(commit.metadata, "timestamp", nothing)),
            tape_record_ord,
            ctx_file[],
            ctx_line[],
        ))
        last_commit_file = ctx_file[]
        last_commit_line = ctx_line[]

        for (scope_ord, scope) in enumerate(commit.scopes)
            _index_scope!(db, session_id, commit_uid, commit_ord, scope_ord, scope)
        end
    end
    return (
        last_indexed_commit_ord = commit_ord,
        last_indexed_tape_record_ord = tape_record_ord,
        last_tape_file = last_commit_file,
        last_tape_line_no = last_commit_line,
    )
end

function _refresh_project_sessions!(db::SQLite.DB, project_driver::Kernel.SimuleosProject)
    seen_session_ids = String[]
    sdir = Kernel.sessions_dir(project_driver.simuleos_dir)
    isdir(sdir) || (_prune_missing_sessions!(db, seen_session_ids); return nothing)

    for entry in sort!(readdir(sdir))
        sjson = Kernel.session_json_path(project_driver, entry)
        isfile(sjson) || continue
        raw = Kernel._read_json_file(sjson)
        session_id = string(get(raw, Kernel.SESSION_FILE_ID_KEY, ""))
        isempty(session_id) && error("Invalid session.json at `$(sjson)`: missing session_id.")
        push!(seen_session_ids, session_id)
        _refresh_session!(db, project_driver, raw, sjson)
    end

    _prune_missing_sessions!(db, seen_session_ids)
    return nothing
end

function _refresh_session!(
        db::SQLite.DB,
        project_driver::Kernel.SimuleosProject,
        raw::Dict{String, Any},
        sjson::String,
    )
    session_id = string(get(raw, Kernel.SESSION_FILE_ID_KEY, ""))
    labels = Kernel._session_labels(raw)
    primary_label = isempty(labels) ? nothing : labels[1]
    meta = Kernel._session_meta(raw)

    if _session_exists(db, session_id)
        _sqlite_exec(db, """
            UPDATE sessions SET
                session_label = ?, session_json_path = ?, session_init_file = ?, session_init_line = ?,
                session_timestamp = ?, session_git_commit = ?, session_git_dirty = ?
            WHERE session_id = ?
        """, (
            primary_label,
            sjson,
            _string_or_nothing(get(meta, Kernel.SESSION_META_INIT_FILE_KEY, nothing)),
            _int_or_nothing(get(meta, Kernel.SESSION_META_INIT_LINE_KEY, nothing)),
            _string_or_nothing(get(meta, Kernel.SESSION_META_TIMESTAMP_KEY, nothing)),
            _string_or_nothing(get(meta, Kernel.SESSION_META_GIT_COMMIT_KEY, nothing)),
            _bool_int_or_nothing(get(meta, Kernel.SESSION_META_GIT_DIRTY_KEY, nothing)),
            session_id,
        ))
        _sqlite_exec(db, "DELETE FROM session_labels WHERE session_id = ?", (session_id,))
    else
        _sqlite_exec(db, """
            INSERT INTO sessions (
                session_id, session_label, session_json_path, session_init_file, session_init_line,
                session_timestamp, session_git_commit, session_git_dirty
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            session_id,
            primary_label,
            sjson,
            _string_or_nothing(get(meta, Kernel.SESSION_META_INIT_FILE_KEY, nothing)),
            _int_or_nothing(get(meta, Kernel.SESSION_META_INIT_LINE_KEY, nothing)),
            _string_or_nothing(get(meta, Kernel.SESSION_META_TIMESTAMP_KEY, nothing)),
            _string_or_nothing(get(meta, Kernel.SESSION_META_GIT_COMMIT_KEY, nothing)),
            _bool_int_or_nothing(get(meta, Kernel.SESSION_META_GIT_DIRTY_KEY, nothing)),
        ))
    end

    for (label_ord, label) in enumerate(labels)
        _sqlite_exec(db,
            "INSERT INTO session_labels (session_id, label_ord, label) VALUES (?, ?, ?)",
            (session_id, label_ord, label),
        )
    end

    state = _session_index_state(db, session_id)
    stats = if isnothing(state)
        _index_session_tape_incremental!(db, project_driver, session_id; start_commit_ord = 0)
    else
        _index_session_tape_incremental!(db, project_driver, session_id;
            start_commit_ord = Int(state.last_indexed_commit_ord))
    end
    _update_session_index_state!(db, session_id, primary_label, stats; refresh_mode = "incremental")
    return nothing
end

function _index_session_tape_incremental!(
        db::SQLite.DB,
        project_driver::Kernel.SimuleosProject,
        session_id::String;
        start_commit_ord::Int,
    )
    tape = Kernel.TapeIO(Kernel.tape_path(project_driver.simuleos_dir, session_id))

    ctx_file = Ref("")
    ctx_line = Ref(0)
    records = Kernel.each_tape_records_filtered(
        tape;
        line_filter = (line, ctx) -> true,
        json_filter = (obj, ctx) -> begin
            ctx_file[] = ctx.file
            ctx_line[] = ctx.line_no
            true
        end,
    )

    tape_record_ord = 0
    commit_ord = 0
    last_commit_file = nothing
    last_commit_line = nothing

    for raw in records
        tape_record_ord += 1
        _record_type(raw) == "commit" || continue
        commit_ord += 1

        commit = Kernel._parse_commit(raw)
        last_commit_file = ctx_file[]
        last_commit_line = ctx_line[]

        if commit_ord <= start_commit_ord
            _verify_indexed_commit_prefix!(db, session_id, commit_ord, commit, tape_record_ord, ctx_file[], ctx_line[])
            continue
        end

        commit_uid = _commit_uid(session_id, commit_ord)
        _sqlite_exec(db, """
            INSERT INTO commits (
                commit_uid, session_id, commit_ord, commit_label, commit_timestamp,
                tape_record_ord, tape_file, tape_line_no
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            commit_uid,
            session_id,
            commit_ord,
            commit.commit_label,
            _string_or_nothing(get(commit.metadata, "timestamp", nothing)),
            tape_record_ord,
            ctx_file[],
            ctx_line[],
        ))
        for (scope_ord, scope) in enumerate(commit.scopes)
            _index_scope!(db, session_id, commit_uid, commit_ord, scope_ord, scope)
        end
    end

    if commit_ord < start_commit_ord
        throw(_SQLiteIndexDriftError(
            "SQLite metadata index drift: session `$(session_id)` tape has fewer commits than indexed state."
        ))
    end

    return (
        last_indexed_commit_ord = commit_ord,
        last_indexed_tape_record_ord = tape_record_ord,
        last_tape_file = last_commit_file,
        last_tape_line_no = last_commit_line,
    )
end

function _verify_indexed_commit_prefix!(
        db::SQLite.DB,
        session_id::String,
        commit_ord::Int,
        commit::Kernel.ScopeCommit,
        tape_record_ord::Int,
        tape_file::String,
        tape_line_no::Int,
    )
    row = _sqlite_one_or_nothing(db, """
        SELECT commit_uid, commit_label, tape_record_ord, tape_file, tape_line_no
        FROM commits
        WHERE session_id = ? AND commit_ord = ?
    """, (session_id, commit_ord))
    isnothing(row) && throw(_SQLiteIndexDriftError(
        "SQLite metadata index drift: missing indexed commit prefix for session `$(session_id)` commit_ord=$(commit_ord)."
    ))

    if row[:commit_uid] != _commit_uid(session_id, commit_ord) ||
       row[:commit_label] != commit.commit_label ||
       row[:tape_record_ord] != tape_record_ord ||
       row[:tape_file] != tape_file ||
       row[:tape_line_no] != tape_line_no
        throw(_SQLiteIndexDriftError(
            "SQLite metadata index drift: indexed commit prefix mismatch for session `$(session_id)` commit_ord=$(commit_ord)."
        ))
    end
    return nothing
end

function _update_session_index_state!(
        db::SQLite.DB,
        session_id::String,
        session_label,
        stats;
        refresh_mode::String,
    )
    _sqlite_exec(db, """
        INSERT INTO session_index_state (
            session_id, session_label, last_indexed_commit_ord, last_indexed_tape_record_ord,
            last_tape_file, last_tape_line_no, last_refresh_at, refresh_mode
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(session_id) DO UPDATE SET
            session_label = excluded.session_label,
            last_indexed_commit_ord = excluded.last_indexed_commit_ord,
            last_indexed_tape_record_ord = excluded.last_indexed_tape_record_ord,
            last_tape_file = excluded.last_tape_file,
            last_tape_line_no = excluded.last_tape_line_no,
            last_refresh_at = excluded.last_refresh_at,
            refresh_mode = excluded.refresh_mode
    """, (
        session_id,
        session_label,
        Int(stats.last_indexed_commit_ord),
        Int(stats.last_indexed_tape_record_ord),
        _string_or_nothing(stats.last_tape_file),
        _int_or_nothing(stats.last_tape_line_no),
        string(Dates.now()),
        refresh_mode,
    ))
    return nothing
end

function _prune_missing_sessions!(db::SQLite.DB, seen_session_ids::Vector{String})
    indexed = _sqlite_all_dicts(db, "SELECT session_id FROM sessions")
    seen = Set(seen_session_ids)
    for row in indexed
        sid = row[:session_id]
        sid in seen && continue
        _sqlite_exec(db, "DELETE FROM sessions WHERE session_id = ?", (sid,))
    end
    return nothing
end

function _index_scope!(
        db::SQLite.DB,
        session_id::String,
        commit_uid::String,
        commit_ord::Int,
        scope_ord::Int,
        scope::Kernel.SimuleosScope,
    )
    scope_uid = _scope_uid(session_id, commit_ord, scope_ord)

    _sqlite_exec(db, """
        INSERT INTO scopes (
            scope_uid, commit_uid, session_id, commit_ord, scope_ord,
            src_file, src_line, threadid
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    """, (
        scope_uid,
        commit_uid,
        session_id,
        commit_ord,
        scope_ord,
        _string_or_nothing(get(scope.metadata, :src_file, nothing)),
        _int_or_nothing(get(scope.metadata, :src_line, nothing)),
        _int_or_nothing(get(scope.metadata, :threadid, nothing)),
    ))

    for (label_ord, label) in enumerate(scope.labels)
        _sqlite_exec(db,
            "INSERT INTO scope_labels (scope_uid, label_ord, label) VALUES (?, ?, ?)",
            (scope_uid, label_ord, label),
        )
    end

    var_names = sort!(String[string(name) for name in keys(scope.variables)])
    for (var_ord, var_name) in enumerate(var_names)
        var = scope.variables[Symbol(var_name)]
        storage_kind, scope_level, type_short, blob_ref, hash_ref = _scope_var_parts(var)
        _sqlite_exec(db, """
            INSERT INTO scope_vars (
                scope_uid, var_name, var_ord, storage_kind, scope_level, type_short, blob_ref, hash_ref
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            scope_uid,
            var_name,
            var_ord,
            storage_kind,
            scope_level,
            type_short,
            blob_ref,
            hash_ref,
        ))
    end

    meta_keys = sort!(Symbol[k for k in keys(scope.metadata)])
    for key in meta_keys
        value = scope.metadata[key]
        kind, text = _meta_value_parts(value)
        _sqlite_exec(db, """
            INSERT INTO scope_meta_kv (scope_uid, meta_key, value_kind, value_text)
            VALUES (?, ?, ?, ?)
        """, (
            scope_uid,
            String(key),
            kind,
            text,
        ))
    end

    return nothing
end

# ------------------------------------------------------------
# Row encoding helpers
# ------------------------------------------------------------

_record_type(raw::AbstractDict)::String = string(get(raw, "type", "commit"))

_commit_uid(session_id::String, commit_ord::Int)::String = string(session_id, ":c", commit_ord)
_scope_uid(session_id::String, commit_ord::Int, scope_ord::Int)::String =
    string(session_id, ":c", commit_ord, ":s", scope_ord)

_string_or_nothing(x) = x isa AbstractString ? String(x) : (isnothing(x) ? nothing : string(x))

function _int_or_nothing(x)
    x isa Integer && return Int(x)
    return nothing
end

function _bool_int_or_nothing(x)
    x isa Bool && return x ? 1 : 0
    return nothing
end

function _scope_var_parts(var::Kernel.ScopeVariable)
    if var isa Kernel.InlineScopeVariable
        return ("inline", String(var.level), var.type_short, nothing, nothing)
    elseif var isa Kernel.BlobScopeVariable
        return ("blob", String(var.level), var.type_short, var.blob_ref.hash, nothing)
    elseif var isa Kernel.VoidScopeVariable
        return ("void", String(var.level), var.type_short, nothing, nothing)
    elseif var isa Kernel.HashedScopeVariable
        return ("hash", String(var.level), var.type_short, nothing, var.value_hash)
    end
    error("Unsupported scope variable type: $(typeof(var))")
end

function _meta_value_parts(value)::Tuple{String, Union{Nothing, String}}
    if value === nothing
        return ("null", nothing)
    elseif value isa Missing
        return ("missing", nothing)
    elseif value isa AbstractString
        return ("string", String(value))
    elseif value isa Bool
        return ("bool", value ? "true" : "false")
    elseif value isa Integer
        return ("int", string(value))
    elseif value isa AbstractFloat
        return ("float", repr(value))
    elseif value isa Symbol
        return ("symbol", String(value))
    elseif value isa AbstractDict || value isa AbstractVector
        return ("json", String(Kernel.JSON3.write(value)))
    else
        return ("other", repr(value))
    end
end

# ------------------------------------------------------------
# SQLite row/query helpers (internal)
# ------------------------------------------------------------

function _sqlite_materialize_row(row)::Dict{Symbol, Any}
    names = getfield(getfield(row, :q), :names)
    vals = SQLite.values(row)
    return Dict{Symbol, Any}(Symbol(n) => v for (n, v) in zip(names, vals))
end

function _sqlite_all_dicts(db::SQLite.DB, sql::AbstractString, params = ())
    rows = Dict{Symbol, Any}[]
    for row in SQLite.DBInterface.execute(db, String(sql), params)
        push!(rows, _sqlite_materialize_row(row))
    end
    return rows
end

function _sqlite_one_or_nothing(db::SQLite.DB, sql::AbstractString, params = ())
    rows = _sqlite_all_dicts(db, sql, params)
    isempty(rows) && return nothing
    length(rows) == 1 || error("Expected 0 or 1 row, got $(length(rows)).")
    return rows[1]
end

function _sqlite_table_exists(db::SQLite.DB, table_name::AbstractString)::Bool
    row = _sqlite_one_or_nothing(db,
        "SELECT 1 AS ok FROM sqlite_master WHERE type = 'table' AND name = ?",
        (String(table_name),),
    )
    return !isnothing(row)
end

function _session_exists(db::SQLite.DB, session_id::String)::Bool
    row = _sqlite_one_or_nothing(db,
        "SELECT 1 AS ok FROM sessions WHERE session_id = ?",
        (session_id,),
    )
    return !isnothing(row)
end

function _session_index_state(db::SQLite.DB, session_id::String)
    row = _sqlite_one_or_nothing(db, """
        SELECT session_id, session_label, last_indexed_commit_ord, last_indexed_tape_record_ord,
               last_tape_file, last_tape_line_no, last_refresh_at, refresh_mode
        FROM session_index_state
        WHERE session_id = ?
    """, (session_id,))
    return isnothing(row) ? nothing : (
        session_id = String(row[:session_id]),
        session_label = row[:session_label],
        last_indexed_commit_ord = Int(row[:last_indexed_commit_ord]),
        last_indexed_tape_record_ord = Int(row[:last_indexed_tape_record_ord]),
        last_tape_file = row[:last_tape_file],
        last_tape_line_no = row[:last_tape_line_no],
        last_refresh_at = row[:last_refresh_at],
        refresh_mode = row[:refresh_mode],
    )
end

function _is_refresh_capable_index_db(db::SQLite.DB, project_driver::Kernel.SimuleosProject)::Bool
    for t in ("index_manifest", "sessions", "session_labels", "commits", "scopes", "scope_labels", "scope_vars", "scope_meta_kv", "session_index_state")
        _sqlite_table_exists(db, t) || return false
    end

    manifest = _sqlite_one_or_nothing(db, """
        SELECT schema_version, index_kind, project_root, simuleos_dir
        FROM index_manifest
        WHERE manifest_id = 1
    """)
    isnothing(manifest) && return false
    manifest[:schema_version] == SQLITE_INDEX_SCHEMA_VERSION || return false
    manifest[:index_kind] == "simuleos_metadata" || return false
    String(manifest[:project_root]) == project_driver.root_path || return false
    String(manifest[:simuleos_dir]) == project_driver.simuleos_dir || return false
    return true
end

end # module SQLiteIndex
