# ------------------------------------------------------------
# SQLiteIndex Scope Adapter (Phase 4B)
# ------------------------------------------------------------

function _scope_sqlite_index_adapter_spec()
    return (
        subsystem_id = _SQLITE_INDEX_SCOPE_SUBSYSTEM_ID,
        adapter_version = _SQLITE_INDEX_SCOPE_ADAPTER_VERSION,
        required_tables = (
            "sessions",
            "session_labels",
            "session_index_state",
            "commits",
            "scopes",
            "scope_labels",
            "scope_vars",
            "scope_meta_kv",
        ),
        drop_view_names = (
            "v_scope_meta_inventory",
            "v_scope_vars_inventory",
            "v_scope_labels_flat",
            "v_scope_inventory",
            "v_commits",
            "v_sessions",
        ),
        create_schema! = _scope_adapter_create_schema!,
        rebuild_index! = _scope_adapter_rebuild_index!,
        refresh_index! = _scope_adapter_refresh_index!,
        recreate_views! = _scope_adapter_recreate_views!,
    )
end

function _scope_adapter_create_schema!(db::SQLite.DB)
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

function _scope_adapter_rebuild_index!(db::SQLite.DB, project_driver::Kernel.SimuleosProject)
    _index_project_sessions!(db, project_driver; refresh_mode = "rebuild")
    return nothing
end

function _scope_adapter_refresh_index!(db::SQLite.DB, project_driver::Kernel.SimuleosProject)
    _refresh_project_sessions!(db, project_driver)
    return nothing
end

function _scope_adapter_recreate_views!(db::SQLite.DB)
    _sqlite_exec(db, """
        CREATE VIEW v_sessions AS
        SELECT
            s.session_id,
            s.session_label,
            s.session_json_path,
            s.session_init_file,
            s.session_init_line,
            s.session_timestamp,
            s.session_git_commit,
            s.session_git_dirty,
            (
                SELECT group_concat(label, ';')
                FROM (
                    SELECT sl.label
                    FROM session_labels sl
                    WHERE sl.session_id = s.session_id
                    ORDER BY sl.label_ord
                )
            ) AS session_labels_csv,
            (
                SELECT COUNT(*)
                FROM commits c
                WHERE c.session_id = s.session_id
            ) AS commit_count,
            (
                SELECT COUNT(*)
                FROM scopes sc
                WHERE sc.session_id = s.session_id
            ) AS scope_count,
            sis.last_indexed_commit_ord,
            sis.last_indexed_tape_record_ord,
            sis.last_tape_file,
            sis.last_tape_line_no,
            sis.last_refresh_at,
            sis.refresh_mode
        FROM sessions s
        LEFT JOIN session_index_state sis ON sis.session_id = s.session_id
    """)

    _sqlite_exec(db, """
        CREATE VIEW v_commits AS
        SELECT
            c.commit_uid,
            c.session_id,
            s.session_label,
            c.commit_ord,
            c.commit_label,
            c.commit_timestamp,
            c.tape_record_ord,
            c.tape_file,
            c.tape_line_no,
            (
                SELECT COUNT(*)
                FROM scopes sc
                WHERE sc.commit_uid = c.commit_uid
            ) AS scope_count
        FROM commits c
        JOIN sessions s ON s.session_id = c.session_id
    """)

    _sqlite_exec(db, """
        CREATE VIEW v_scope_inventory AS
        SELECT
            sc.scope_uid,
            sc.commit_uid,
            sc.session_id,
            s.session_label,
            sc.commit_ord,
            c.commit_label,
            c.commit_timestamp,
            c.tape_record_ord,
            c.tape_file,
            c.tape_line_no,
            sc.scope_ord,
            sc.src_file,
            sc.src_line,
            sc.threadid,
            (
                SELECT COUNT(*)
                FROM scope_labels sl
                WHERE sl.scope_uid = sc.scope_uid
            ) AS scope_label_count,
            (
                SELECT group_concat(label, ';')
                FROM (
                    SELECT sl2.label
                    FROM scope_labels sl2
                    WHERE sl2.scope_uid = sc.scope_uid
                    ORDER BY sl2.label_ord
                )
            ) AS scope_labels_csv,
            (
                SELECT COUNT(*)
                FROM scope_vars sv
                WHERE sv.scope_uid = sc.scope_uid
            ) AS scope_var_count,
            (
                SELECT COUNT(*)
                FROM scope_meta_kv mk
                WHERE mk.scope_uid = sc.scope_uid
            ) AS scope_meta_count
        FROM scopes sc
        JOIN commits c ON c.commit_uid = sc.commit_uid
        JOIN sessions s ON s.session_id = sc.session_id
    """)

    _sqlite_exec(db, """
        CREATE VIEW v_scope_labels_flat AS
        SELECT
            sc.scope_uid,
            sl.label_ord AS scope_label_ord,
            sl.label AS scope_label,
            sc.commit_uid,
            sc.session_id,
            s.session_label,
            sc.commit_ord,
            c.commit_label,
            c.commit_timestamp,
            c.tape_record_ord,
            c.tape_file,
            c.tape_line_no,
            sc.scope_ord,
            sc.src_file,
            sc.src_line,
            sc.threadid
        FROM scope_labels sl
        JOIN scopes sc ON sc.scope_uid = sl.scope_uid
        JOIN commits c ON c.commit_uid = sc.commit_uid
        JOIN sessions s ON s.session_id = sc.session_id
    """)

    _sqlite_exec(db, """
        CREATE VIEW v_scope_vars_inventory AS
        SELECT
            sv.scope_uid,
            sv.var_name,
            sv.var_ord,
            sv.storage_kind,
            sv.scope_level,
            sv.type_short,
            sv.blob_ref,
            sv.hash_ref,
            sc.commit_uid,
            sc.session_id,
            s.session_label,
            sc.commit_ord,
            c.commit_label,
            c.commit_timestamp,
            c.tape_record_ord,
            c.tape_file,
            c.tape_line_no,
            sc.scope_ord,
            sc.src_file,
            sc.src_line,
            sc.threadid,
            (
                SELECT group_concat(label, ';')
                FROM (
                    SELECT sl.label
                    FROM scope_labels sl
                    WHERE sl.scope_uid = sc.scope_uid
                    ORDER BY sl.label_ord
                )
            ) AS scope_labels_csv
        FROM scope_vars sv
        JOIN scopes sc ON sc.scope_uid = sv.scope_uid
        JOIN commits c ON c.commit_uid = sc.commit_uid
        JOIN sessions s ON s.session_id = sc.session_id
    """)

    _sqlite_exec(db, """
        CREATE VIEW v_scope_meta_inventory AS
        SELECT
            mk.scope_uid,
            mk.meta_key,
            mk.value_kind,
            mk.value_text,
            sc.commit_uid,
            sc.session_id,
            s.session_label,
            sc.commit_ord,
            c.commit_label,
            c.commit_timestamp,
            c.tape_record_ord,
            c.tape_file,
            c.tape_line_no,
            sc.scope_ord,
            sc.src_file,
            sc.src_line,
            sc.threadid,
            (
                SELECT group_concat(label, ';')
                FROM (
                    SELECT sl.label
                    FROM scope_labels sl
                    WHERE sl.scope_uid = sc.scope_uid
                    ORDER BY sl.label_ord
                )
            ) AS scope_labels_csv
        FROM scope_meta_kv mk
        JOIN scopes sc ON sc.scope_uid = mk.scope_uid
        JOIN commits c ON c.commit_uid = sc.commit_uid
        JOIN sessions s ON s.session_id = sc.session_id
    """)

    return nothing
end
