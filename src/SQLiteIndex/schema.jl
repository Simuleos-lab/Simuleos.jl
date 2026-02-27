# ------------------------------------------------------------
# Adapter registry
# ------------------------------------------------------------

_sqlite_index_adapters() = (
    _scope_sqlite_index_adapter_spec(),
    _blob_sqlite_index_adapter_spec(),
)

function _create_registered_subsystem_schemas!(db::SQLite.DB)
    for adapter in _sqlite_index_adapters()
        adapter.create_schema!(db)
    end
    return nothing
end

function _index_registered_subsystems_rebuild!(db::SQLite.DB, project_driver::Kernel.SimuleosProject)
    for adapter in _sqlite_index_adapters()
        adapter.rebuild_index!(db, project_driver)
    end
    return nothing
end

function _refresh_registered_subsystems!(db::SQLite.DB, project_driver::Kernel.SimuleosProject)
    for adapter in _sqlite_index_adapters()
        adapter.refresh_index!(db, project_driver)
    end
    return nothing
end

function _drop_registered_subsystem_views!(db::SQLite.DB)
    for adapter in _sqlite_index_adapters()
        for view_name in adapter.drop_view_names
            _sqlite_exec(db, "DROP VIEW IF EXISTS $(view_name)")
        end
    end
    return nothing
end

function _recreate_registered_subsystem_views!(db::SQLite.DB)
    for adapter in _sqlite_index_adapters()
        adapter.recreate_views!(db)
    end
    return nothing
end

function _registered_adapter_required_tables()::Vector{String}
    out = String[]
    seen = Set{String}()
    for adapter in _sqlite_index_adapters()
        for t in adapter.required_tables
            ts = String(t)
            ts in seen && continue
            push!(out, ts)
            push!(seen, ts)
        end
    end
    return out
end

function _sqlite_index_builder_version()::String
    adapter_parts = String[]
    for adapter in _sqlite_index_adapters()
        push!(adapter_parts, string(adapter.subsystem_id, "=", adapter.adapter_version))
    end
    sort!(adapter_parts)
    return string("schema=", SQLITE_INDEX_SCHEMA_VERSION, ";adapters=", join(adapter_parts, ","))
end

# ------------------------------------------------------------
# Schema and views
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
        CREATE TABLE subsystems (
            subsystem_id TEXT PRIMARY KEY,
            adapter_version TEXT NOT NULL,
            enabled INTEGER NOT NULL
        )
    """)

    _sqlite_exec(db, """
        CREATE TABLE tapes (
            tape_uid TEXT PRIMARY KEY,
            subsystem_id TEXT NOT NULL,
            logical_owner_id TEXT,
            tape_role TEXT,
            tape_path TEXT NOT NULL,
            tape_relpath TEXT,
            exists_on_disk INTEGER NOT NULL,
            last_seen_at TEXT NOT NULL,
            FOREIGN KEY(subsystem_id) REFERENCES subsystems(subsystem_id) ON DELETE RESTRICT
        )
    """)
    _sqlite_exec(db, "CREATE INDEX idx_tapes_subsystem_id ON tapes(subsystem_id)")
    _sqlite_exec(db, "CREATE INDEX idx_tapes_owner ON tapes(subsystem_id, logical_owner_id)")
    _sqlite_exec(db, "CREATE INDEX idx_tapes_tape_path ON tapes(tape_path)")

    # `record_type` is the generic tape-envelope `type` field.
    # `subsystem_record_kind` is a reserved normalization slot for adapter-specific
    # classification. It currently defaults to `record_type`, but stays separate so
    # adapters can expose a stable subsystem taxonomy without changing generic tape
    # envelope semantics or SQL consumers.
    _sqlite_exec(db, """
        CREATE TABLE tape_records (
            tape_uid TEXT NOT NULL,
            record_ord INTEGER NOT NULL,
            record_type TEXT,
            writer TEXT,
            timetag TEXT,
            file_path TEXT NOT NULL,
            line_no INTEGER NOT NULL,
            record_hash TEXT,
            subsystem_record_kind TEXT,
            PRIMARY KEY (tape_uid, record_ord),
            FOREIGN KEY(tape_uid) REFERENCES tapes(tape_uid) ON DELETE CASCADE
        )
    """)
    _sqlite_exec(db, "CREATE INDEX idx_tape_records_tape_uid_record_type ON tape_records(tape_uid, record_type)")
    _sqlite_exec(db, "CREATE INDEX idx_tape_records_record_type ON tape_records(record_type)")
    _sqlite_exec(db, "CREATE INDEX idx_tape_records_record_hash ON tape_records(record_hash)")

    _sqlite_exec(db, """
        CREATE TABLE tape_index_state (
            tape_uid TEXT PRIMARY KEY,
            subsystem_id TEXT NOT NULL,
            last_indexed_record_ord INTEGER NOT NULL,
            last_file_path TEXT,
            last_line_no INTEGER,
            last_record_hash TEXT,
            last_refresh_at TEXT NOT NULL,
            refresh_mode TEXT NOT NULL,
            drift_status TEXT,
            FOREIGN KEY(tape_uid) REFERENCES tapes(tape_uid) ON DELETE CASCADE,
            FOREIGN KEY(subsystem_id) REFERENCES subsystems(subsystem_id) ON DELETE RESTRICT
        )
    """)
    _sqlite_exec(db, "CREATE INDEX idx_tape_index_state_subsystem_id ON tape_index_state(subsystem_id)")

    _create_registered_subsystem_schemas!(db)

    return nothing
end

function _recreate_public_views!(db::SQLite.DB)
    for view_name in (
            "v_tape_index_state",
            "v_tape_records",
            "v_tapes",
        )
        _sqlite_exec(db, "DROP VIEW IF EXISTS $(view_name)")
    end
    _drop_registered_subsystem_views!(db)

    _sqlite_exec(db, """
        CREATE VIEW v_tapes AS
        SELECT
            t.tape_uid,
            t.subsystem_id,
            t.logical_owner_id,
            t.tape_role,
            t.tape_path,
            t.tape_relpath,
            t.exists_on_disk,
            t.last_seen_at,
            (
                SELECT COUNT(*)
                FROM tape_records tr
                WHERE tr.tape_uid = t.tape_uid
            ) AS record_count,
            tis.last_indexed_record_ord,
            tis.last_file_path,
            tis.last_line_no,
            tis.last_record_hash,
            tis.last_refresh_at,
            tis.refresh_mode,
            tis.drift_status
        FROM tapes t
        LEFT JOIN tape_index_state tis ON tis.tape_uid = t.tape_uid
    """)

    _sqlite_exec(db, """
        CREATE VIEW v_tape_records AS
        SELECT
            tr.tape_uid,
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
            tr.subsystem_record_kind
        FROM tape_records tr
        JOIN tapes t ON t.tape_uid = tr.tape_uid
    """)

    _sqlite_exec(db, """
        CREATE VIEW v_tape_index_state AS
        SELECT
            tis.tape_uid,
            t.subsystem_id,
            t.logical_owner_id,
            t.tape_role,
            t.tape_path,
            t.tape_relpath,
            tis.last_indexed_record_ord,
            tis.last_file_path,
            tis.last_line_no,
            tis.last_record_hash,
            tis.last_refresh_at,
            tis.refresh_mode,
            tis.drift_status
        FROM tape_index_state tis
        JOIN tapes t ON t.tape_uid = tis.tape_uid
    """)
    _recreate_registered_subsystem_views!(db)

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
        SQLITE_INDEX_KIND,
        now_s,
        now_s,
        project_driver.root_path,
        project_driver.simuleos_dir,
        _sqlite_index_builder_version(),
    ))
    return nothing
end

function _touch_manifest_updated_at!(db::SQLite.DB)
    _sqlite_exec(db,
        "UPDATE index_manifest SET updated_at = ?, builder_version = ? WHERE manifest_id = 1",
        (string(Dates.now()), _sqlite_index_builder_version()),
    )
    return nothing
end

function _ensure_builtin_subsystems!(db::SQLite.DB)
    for adapter in _sqlite_index_adapters()
        _sqlite_exec(db, """
            INSERT INTO subsystems (subsystem_id, adapter_version, enabled)
            VALUES (?, ?, 1)
            ON CONFLICT(subsystem_id) DO UPDATE SET
                adapter_version = excluded.adapter_version,
                enabled = 1
        """, (
            adapter.subsystem_id,
            adapter.adapter_version,
        ))
    end
    return nothing
end

function _is_refresh_capable_index_db(db::SQLite.DB, project_driver::Kernel.SimuleosProject)::Bool
    for t in ("index_manifest", "subsystems", "tapes", "tape_records", "tape_index_state")
        _sqlite_table_exists(db, t) || return false
    end
    for t in _registered_adapter_required_tables()
        _sqlite_table_exists(db, t) || return false
    end

    manifest = _sqlite_one_or_nothing(db, """
        SELECT schema_version, index_kind, project_root, simuleos_dir
        FROM index_manifest
        WHERE manifest_id = 1
    """)
    isnothing(manifest) && return false
    manifest[:schema_version] == SQLITE_INDEX_SCHEMA_VERSION || return false
    manifest[:index_kind] == SQLITE_INDEX_KIND || return false
    String(manifest[:project_root]) == project_driver.root_path || return false
    String(manifest[:simuleos_dir]) == project_driver.simuleos_dir || return false
    return true
end
