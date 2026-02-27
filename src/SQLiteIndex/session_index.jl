# ------------------------------------------------------------
# Session/scope indexing
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
    session_doc = _session_index_document(raw, sjson)
    _write_session_and_labels!(db, session_doc; allow_existing = false)

    stats = _index_session_tape!(db, project_driver, session_doc.session_id)
    _update_session_index_state!(db, session_doc.session_id, session_doc.primary_label, stats; refresh_mode = refresh_mode)
    _update_scope_tape_index_state!(db, project_driver, session_doc.session_id, stats; refresh_mode = refresh_mode)
    return nothing
end

function _refresh_project_sessions!(db::SQLite.DB, project_driver::Kernel.SimuleosProject)
    seen_session_ids = String[]
    sdir = Kernel.sessions_dir(project_driver.simuleos_dir)
    isdir(sdir) || (_prune_missing_sessions!(db, seen_session_ids); return nothing)

    for entry in sort!(readdir(sdir))
        sjson = Kernel.session_json_path(project_driver, entry)
        isfile(sjson) || continue

        raw = Kernel._read_json_file(sjson)
        session_doc = _session_index_document(raw, sjson)
        push!(seen_session_ids, session_doc.session_id)

        _refresh_session!(db, project_driver, session_doc)
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
    session_doc = _session_index_document(raw, sjson)
    return _refresh_session!(db, project_driver, session_doc)
end

function _refresh_session!(
        db::SQLite.DB,
        project_driver::Kernel.SimuleosProject,
        session_doc,
    )
    _write_session_and_labels!(db, session_doc; allow_existing = true)

    state = _session_index_state(db, session_doc.session_id)
    start_commit_ord = isnothing(state) ? 0 : Int(state.last_indexed_commit_ord)
    start_tape_record_ord = isnothing(state) ? 0 : Int(state.last_indexed_tape_record_ord)

    stats = _index_session_tape_incremental!(db, project_driver, session_doc.session_id;
        start_commit_ord = start_commit_ord,
        start_tape_record_ord = start_tape_record_ord,
    )

    _update_session_index_state!(db, session_doc.session_id, session_doc.primary_label, stats; refresh_mode = "incremental")
    _update_scope_tape_index_state!(db, project_driver, session_doc.session_id, stats; refresh_mode = "incremental")
    return nothing
end

function _session_index_document(raw::Dict{String, Any}, sjson::String)
    session_id = string(get(raw, Kernel.SESSION_FILE_ID_KEY, ""))
    isempty(session_id) && error("Invalid session.json at `$(sjson)`: missing session_id.")

    labels = Kernel._session_labels(raw)
    primary_label = isempty(labels) ? nothing : labels[1]
    meta = Kernel._session_meta(raw)

    return (
        session_id = session_id,
        primary_label = primary_label,
        labels = labels,
        session_json_path = sjson,
        session_init_file = _string_or_nothing(get(meta, Kernel.SESSION_META_INIT_FILE_KEY, nothing)),
        session_init_line = _int_or_nothing(get(meta, Kernel.SESSION_META_INIT_LINE_KEY, nothing)),
        session_timestamp = _string_or_nothing(get(meta, Kernel.SESSION_META_TIMESTAMP_KEY, nothing)),
        session_git_commit = _string_or_nothing(get(meta, Kernel.SESSION_META_GIT_COMMIT_KEY, nothing)),
        session_git_dirty = _bool_int_or_nothing(get(meta, Kernel.SESSION_META_GIT_DIRTY_KEY, nothing)),
    )
end

function _write_session_and_labels!(db::SQLite.DB, session_doc; allow_existing::Bool)
    if allow_existing
        _sqlite_exec(db, """
            INSERT INTO sessions (
                session_id, session_label, session_json_path, session_init_file, session_init_line,
                session_timestamp, session_git_commit, session_git_dirty
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(session_id) DO UPDATE SET
                session_label = excluded.session_label,
                session_json_path = excluded.session_json_path,
                session_init_file = excluded.session_init_file,
                session_init_line = excluded.session_init_line,
                session_timestamp = excluded.session_timestamp,
                session_git_commit = excluded.session_git_commit,
                session_git_dirty = excluded.session_git_dirty
        """, (
            session_doc.session_id,
            session_doc.primary_label,
            session_doc.session_json_path,
            session_doc.session_init_file,
            session_doc.session_init_line,
            session_doc.session_timestamp,
            session_doc.session_git_commit,
            session_doc.session_git_dirty,
        ))
    else
        _sqlite_exec(db, """
            INSERT INTO sessions (
                session_id, session_label, session_json_path, session_init_file, session_init_line,
                session_timestamp, session_git_commit, session_git_dirty
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            session_doc.session_id,
            session_doc.primary_label,
            session_doc.session_json_path,
            session_doc.session_init_file,
            session_doc.session_init_line,
            session_doc.session_timestamp,
            session_doc.session_git_commit,
            session_doc.session_git_dirty,
        ))
    end

    _sqlite_exec(db, "DELETE FROM session_labels WHERE session_id = ?", (session_doc.session_id,))
    for (label_ord, label) in enumerate(session_doc.labels)
        _sqlite_exec(db,
            "INSERT INTO session_labels (session_id, label_ord, label) VALUES (?, ?, ?)",
            (session_doc.session_id, label_ord, label),
        )
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
        _delete_scope_tape_catalog!(db, String(sid))
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
        scope::Kernel.ScopeSnapshot,
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
