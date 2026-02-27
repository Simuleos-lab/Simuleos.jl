# ------------------------------------------------------------
# SQLiteIndex Blob Adapter (Phase 4C)
# ------------------------------------------------------------

function _blob_sqlite_index_adapter_spec()
    return (
        subsystem_id = _SQLITE_INDEX_BLOB_SUBSYSTEM_ID,
        adapter_version = _SQLITE_INDEX_BLOB_ADAPTER_VERSION,
        required_tables = (
            "blob_records",
        ),
        drop_view_names = (
            "v_blob_inventory",
            "v_blob_latest_meta",
            "v_blob_events",
        ),
        create_schema! = _blob_adapter_create_schema!,
        rebuild_index! = _blob_adapter_rebuild_index!,
        refresh_index! = _blob_adapter_refresh_index!,
        recreate_views! = _blob_adapter_recreate_views!,
    )
end

function _blob_adapter_create_schema!(db::SQLite.DB)
    _sqlite_exec(db, """
        CREATE TABLE blob_records (
            tape_uid TEXT NOT NULL,
            record_ord INTEGER NOT NULL,
            schema TEXT,
            blob_hash TEXT NOT NULL,
            hash_prefix TEXT,
            blob_relpath TEXT,
            blob_ext TEXT,
            serializer TEXT,
            format TEXT,
            payload_hash_alg TEXT,
            payload_hash TEXT,
            byte_size INTEGER,
            replaced_existing INTEGER,
            created_at TEXT,
            PRIMARY KEY (tape_uid, record_ord),
            FOREIGN KEY(tape_uid, record_ord) REFERENCES tape_records(tape_uid, record_ord) ON DELETE CASCADE
        )
    """)
    _sqlite_exec(db, "CREATE INDEX idx_blob_records_blob_hash ON blob_records(blob_hash)")
    _sqlite_exec(db, "CREATE INDEX idx_blob_records_hash_prefix ON blob_records(hash_prefix)")
    _sqlite_exec(db, "CREATE INDEX idx_blob_records_created_at ON blob_records(created_at)")
    return nothing
end

function _blob_adapter_rebuild_index!(db::SQLite.DB, project_driver::Kernel.SimuleosProject)
    for tape_path in _blob_adapter_discover_tape_paths(project_driver)
        stats = _blob_adapter_index_tape_incremental!(db, project_driver, tape_path; start_record_ord = 0)
        _blob_adapter_update_tape_index_state!(db, stats; refresh_mode = "rebuild")
    end
    return nothing
end

function _blob_adapter_refresh_index!(db::SQLite.DB, project_driver::Kernel.SimuleosProject)
    seen_tape_uids = String[]
    for tape_path in _blob_adapter_discover_tape_paths(project_driver)
        tape_info = _blob_adapter_tape_info(project_driver, tape_path)
        push!(seen_tape_uids, tape_info.tape_uid)
        state = _blob_adapter_tape_index_state(db, tape_info.tape_uid)
        start_record_ord = isnothing(state) ? 0 : Int(state.last_indexed_record_ord)
        stats = _blob_adapter_index_tape_incremental!(db, project_driver, tape_path; start_record_ord = start_record_ord)
        _blob_adapter_update_tape_index_state!(db, stats; refresh_mode = "incremental")
    end
    _blob_adapter_prune_missing_tapes!(db, seen_tape_uids)
    return nothing
end

function _blob_adapter_recreate_views!(db::SQLite.DB)
    _sqlite_exec(db, """
        CREATE VIEW v_blob_events AS
        SELECT
            br.tape_uid,
            t.subsystem_id,
            t.logical_owner_id,
            t.tape_role,
            t.tape_path,
            t.tape_relpath,
            tr.record_ord,
            tr.record_type,
            tr.writer,
            tr.timetag,
            tr.file_path,
            tr.line_no,
            tr.record_hash,
            br.schema,
            br.blob_hash,
            br.hash_prefix,
            br.blob_relpath,
            br.blob_ext,
            br.serializer,
            br.format,
            br.payload_hash_alg,
            br.payload_hash,
            br.byte_size,
            br.replaced_existing,
            br.created_at
        FROM blob_records br
        JOIN tape_records tr
          ON tr.tape_uid = br.tape_uid
         AND tr.record_ord = br.record_ord
        JOIN tapes t
          ON t.tape_uid = br.tape_uid
    """)

    _sqlite_exec(db, """
        CREATE VIEW v_blob_latest_meta AS
        SELECT e.*
        FROM v_blob_events e
        WHERE NOT EXISTS (
            SELECT 1
            FROM v_blob_events e2
            WHERE e2.blob_hash = e.blob_hash
              AND (
                    COALESCE(e2.created_at, '') > COALESCE(e.created_at, '')
                 OR (
                        COALESCE(e2.created_at, '') = COALESCE(e.created_at, '')
                    AND (
                            e2.tape_uid > e.tape_uid
                         OR (e2.tape_uid = e.tape_uid AND e2.record_ord > e.record_ord)
                    )
                 )
              )
        )
    """)

    _sqlite_exec(db, """
        CREATE VIEW v_blob_inventory AS
        SELECT
            l.*,
            (
                SELECT COUNT(*)
                FROM blob_records br
                WHERE br.blob_hash = l.blob_hash
            ) AS event_count
        FROM v_blob_latest_meta l
    """)

    return nothing
end

function _blob_adapter_discover_tape_paths(project_driver::Kernel.SimuleosProject)::Vector{String}
    tdir = Kernel.blob_tapes_dir(project_driver.blobstorage)
    isdir(tdir) || return String[]

    paths = String[]
    for entry in readdir(tdir; join = true)
        isfile(entry) || continue
        endswith(lowercase(entry), ".jsonl") || continue
        push!(paths, abspath(entry))
    end
    sort!(paths)
    return paths
end

function _blob_adapter_tape_info(project_driver::Kernel.SimuleosProject, tape_path::AbstractString)
    tape_path_s = abspath(String(tape_path))
    rel = _path_rel_to_project(project_driver, tape_path_s)
    shard = _blob_adapter_shard_from_tape_path(tape_path_s)
    return (
        tape_uid = _blob_adapter_tape_uid(project_driver, tape_path_s),
        subsystem_id = _SQLITE_INDEX_BLOB_SUBSYSTEM_ID,
        logical_owner_id = shard,
        tape_role = "metadata_shard",
        tape_path = tape_path_s,
        tape_relpath = rel,
        exists_on_disk = (ispath(tape_path_s) ? 1 : 0),
    )
end

function _blob_adapter_tape_uid(project_driver::Kernel.SimuleosProject, tape_path::AbstractString)::String
    rel = _path_rel_to_project(project_driver, String(tape_path))
    return string(_SQLITE_INDEX_BLOB_SUBSYSTEM_ID, ":", rel)
end

function _blob_adapter_shard_from_tape_path(tape_path::AbstractString)::String
    base = splitext(basename(String(tape_path)))[1]
    return lowercase(base)
end

function _blob_adapter_tape_index_state(db::SQLite.DB, tape_uid::String)
    row = _sqlite_one_or_nothing(db, """
        SELECT tape_uid, subsystem_id, last_indexed_record_ord, last_file_path, last_line_no,
               last_record_hash, last_refresh_at, refresh_mode, drift_status
        FROM tape_index_state
        WHERE tape_uid = ?
    """, (tape_uid,))
    isnothing(row) && return nothing
    return (
        tape_uid = String(row[:tape_uid]),
        subsystem_id = String(row[:subsystem_id]),
        last_indexed_record_ord = Int(row[:last_indexed_record_ord]),
        last_file_path = row[:last_file_path],
        last_line_no = row[:last_line_no],
        last_record_hash = row[:last_record_hash],
        last_refresh_at = row[:last_refresh_at],
        refresh_mode = row[:refresh_mode],
        drift_status = row[:drift_status],
    )
end

function _blob_adapter_update_tape_index_state!(db::SQLite.DB, stats; refresh_mode::String, drift_status::String = "ok")
    _sqlite_exec(db, """
        INSERT INTO tape_index_state (
            tape_uid, subsystem_id, last_indexed_record_ord, last_file_path, last_line_no,
            last_record_hash, last_refresh_at, refresh_mode, drift_status
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(tape_uid) DO UPDATE SET
            subsystem_id = excluded.subsystem_id,
            last_indexed_record_ord = excluded.last_indexed_record_ord,
            last_file_path = excluded.last_file_path,
            last_line_no = excluded.last_line_no,
            last_record_hash = excluded.last_record_hash,
            last_refresh_at = excluded.last_refresh_at,
            refresh_mode = excluded.refresh_mode,
            drift_status = excluded.drift_status
    """, (
        String(stats.tape_uid),
        _SQLITE_INDEX_BLOB_SUBSYSTEM_ID,
        Int(stats.last_indexed_record_ord),
        _string_or_nothing(stats.last_record_file),
        _int_or_nothing(stats.last_record_line_no),
        _string_or_nothing(stats.last_record_hash),
        string(Dates.now()),
        refresh_mode,
        drift_status,
    ))
    return nothing
end

function _blob_adapter_prune_missing_tapes!(db::SQLite.DB, seen_tape_uids::Vector{String})
    seen = Set(seen_tape_uids)
    indexed = _sqlite_all_dicts(db, "SELECT tape_uid FROM tapes WHERE subsystem_id = ?", (_SQLITE_INDEX_BLOB_SUBSYSTEM_ID,))
    for row in indexed
        tape_uid = String(row[:tape_uid])
        tape_uid in seen && continue
        _sqlite_exec(db, "DELETE FROM tapes WHERE tape_uid = ?", (tape_uid,))
    end
    return nothing
end

function _blob_adapter_index_tape_incremental!(
        db::SQLite.DB,
        project_driver::Kernel.SimuleosProject,
        tape_path::AbstractString;
        start_record_ord::Int,
    )
    tape = Kernel.TapeIO(String(tape_path))
    tape_info = _blob_adapter_tape_info(project_driver, String(tape_path))
    _upsert_tape!(db, tape_info)

    record_ord = 0
    last_record_file = nothing
    last_record_line = nothing
    last_record_hash = nothing

    Kernel.scan_tape_records_filtered(
        tape;
        line_filter = (line, ctx) -> true,
        json_filter = (obj, ctx) -> true,
        on_record = function (raw, ctx)
            record_ord += 1
            rec_hash = _record_hash(raw)
            last_record_file = ctx.file
            last_record_line = ctx.line_no
            last_record_hash = rec_hash

            if record_ord <= start_record_ord
                _verify_indexed_tape_record_prefix!(db, tape_info.tape_uid, record_ord, raw, ctx.file, ctx.line_no; record_hash = rec_hash)
                if _record_type(raw) == Kernel._BLOB_RECORD_TYPE
                    _blob_adapter_verify_blob_record_prefix!(db, tape_info.tape_uid, record_ord, raw)
                end
                return nothing
            end

            _insert_tape_record!(db, tape_info.tape_uid, record_ord, raw, ctx.file, ctx.line_no; record_hash = rec_hash)
            if _record_type(raw) == Kernel._BLOB_RECORD_TYPE
                _blob_adapter_insert_blob_record!(db, tape_info.tape_uid, record_ord, raw)
            end
            return nothing
        end,
    )

    if record_ord < start_record_ord
        throw(_SQLiteIndexDriftError(
            "SQLite metadata index drift: blob tape `$(tape_info.tape_uid)` has fewer records than indexed state."
        ))
    end

    return (
        tape_uid = tape_info.tape_uid,
        last_indexed_record_ord = record_ord,
        last_record_file = last_record_file,
        last_record_line_no = last_record_line,
        last_record_hash = last_record_hash,
    )
end

function _blob_adapter_insert_blob_record!(db::SQLite.DB, tape_uid::String, record_ord::Int, raw::AbstractDict)
    parts = _blob_adapter_blob_record_parts(raw)
    _sqlite_exec(db, """
        INSERT INTO blob_records (
            tape_uid, record_ord, schema, blob_hash, hash_prefix, blob_relpath, blob_ext,
            serializer, format, payload_hash_alg, payload_hash, byte_size, replaced_existing, created_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    """, (
        tape_uid,
        record_ord,
        parts.schema,
        parts.blob_hash,
        parts.hash_prefix,
        parts.blob_relpath,
        parts.blob_ext,
        parts.serializer,
        parts.format,
        parts.payload_hash_alg,
        parts.payload_hash,
        parts.byte_size,
        parts.replaced_existing,
        parts.created_at,
    ))
    return nothing
end

function _blob_adapter_verify_blob_record_prefix!(db::SQLite.DB, tape_uid::String, record_ord::Int, raw::AbstractDict)
    row = _sqlite_one_or_nothing(db, """
        SELECT schema, blob_hash, hash_prefix, blob_relpath, blob_ext, serializer, format,
               payload_hash_alg, payload_hash, byte_size, replaced_existing, created_at
        FROM blob_records
        WHERE tape_uid = ? AND record_ord = ?
    """, (tape_uid, record_ord))
    isnothing(row) && throw(_SQLiteIndexDriftError(
        "SQLite metadata index drift: missing blob-record prefix for tape `$(tape_uid)` record_ord=$(record_ord)."
    ))

    parts = _blob_adapter_blob_record_parts(raw)
    if _sqlite_nullable_text(row[:schema]) != parts.schema ||
       String(row[:blob_hash]) != parts.blob_hash ||
       _sqlite_nullable_text(row[:hash_prefix]) != parts.hash_prefix ||
       _sqlite_nullable_text(row[:blob_relpath]) != parts.blob_relpath ||
       _sqlite_nullable_text(row[:blob_ext]) != parts.blob_ext ||
       _sqlite_nullable_text(row[:serializer]) != parts.serializer ||
       _sqlite_nullable_text(row[:format]) != parts.format ||
       _sqlite_nullable_text(row[:payload_hash_alg]) != parts.payload_hash_alg ||
       _sqlite_nullable_text(row[:payload_hash]) != parts.payload_hash ||
       _sqlite_nullable_int(row[:byte_size]) != parts.byte_size ||
       _sqlite_nullable_int(row[:replaced_existing]) != parts.replaced_existing ||
       _sqlite_nullable_text(row[:created_at]) != parts.created_at
        throw(_SQLiteIndexDriftError(
            "SQLite metadata index drift: blob-record prefix mismatch for tape `$(tape_uid)` record_ord=$(record_ord)."
        ))
    end
    return nothing
end

function _blob_adapter_blob_record_parts(raw::AbstractDict)
    blob_hash = _string_or_nothing(get(raw, "blob_hash", get(raw, :blob_hash, nothing)))
    isnothing(blob_hash) && error("Invalid blob_record: missing `blob_hash`.")
    blob_hash_s = lowercase(String(blob_hash))
    hp = _string_or_nothing(get(raw, "hash_prefix", get(raw, :hash_prefix, nothing)))
    hash_prefix = isnothing(hp) ? blob_hash_s[1:2] : lowercase(String(hp))
    return (
        schema = _string_or_nothing(get(raw, "schema", get(raw, :schema, nothing))),
        blob_hash = blob_hash_s,
        hash_prefix = hash_prefix,
        blob_relpath = _string_or_nothing(get(raw, "blob_relpath", get(raw, :blob_relpath, nothing))),
        blob_ext = _string_or_nothing(get(raw, "blob_ext", get(raw, :blob_ext, nothing))),
        serializer = _string_or_nothing(get(raw, "serializer", get(raw, :serializer, nothing))),
        format = _string_or_nothing(get(raw, "format", get(raw, :format, nothing))),
        payload_hash_alg = _string_or_nothing(get(raw, "payload_hash_alg", get(raw, :payload_hash_alg, nothing))),
        payload_hash = _string_or_nothing(get(raw, "payload_hash", get(raw, :payload_hash, nothing))),
        byte_size = _int_or_nothing(get(raw, "byte_size", get(raw, :byte_size, nothing))),
        replaced_existing = _bool_int_or_nothing(get(raw, "replaced_existing", get(raw, :replaced_existing, nothing))),
        created_at = _string_or_nothing(get(raw, "created_at", get(raw, :created_at, nothing))),
    )
end
