# ------------------------------------------------------------
# Tape scanning and indexing helpers
# ------------------------------------------------------------

_record_type(raw::AbstractDict)::String = string(get(raw, "type", "commit"))
_record_writer(raw::AbstractDict) = _string_or_nothing(get(raw, "writer", get(raw, :writer, nothing)))
_record_timetag(raw::AbstractDict) = _string_or_nothing(get(raw, "timetag", get(raw, :timetag, nothing)))
_record_hash(raw::AbstractDict)::String = bytes2hex(SHA.sha1(Kernel.JSON3.write(raw)))

_commit_uid(session_id::String, commit_ord::Int)::String = string(session_id, ":c", commit_ord)
_scope_uid(session_id::String, commit_ord::Int, scope_ord::Int)::String =
    string(session_id, ":c", commit_ord, ":s", scope_ord)

function _index_session_tape!(db::SQLite.DB, project_driver::Kernel.SimuleosProject, session_id::String)
    return _scan_scope_tape!(db, project_driver, session_id;
        verify_prefix = false,
        start_commit_ord = 0,
        start_tape_record_ord = 0,
    )
end

function _index_session_tape_incremental!(
        db::SQLite.DB,
        project_driver::Kernel.SimuleosProject,
        session_id::String;
        start_commit_ord::Int,
        start_tape_record_ord::Int = 0,
    )
    return _scan_scope_tape!(db, project_driver, session_id;
        verify_prefix = true,
        start_commit_ord = start_commit_ord,
        start_tape_record_ord = start_tape_record_ord,
    )
end

function _scan_scope_tape!(
        db::SQLite.DB,
        project_driver::Kernel.SimuleosProject,
        session_id::String;
        verify_prefix::Bool,
        start_commit_ord::Int,
        start_tape_record_ord::Int,
    )
    tape = Kernel.TapeIO(Kernel.tape_path(project_driver.simuleos_dir, session_id))
    tape_info = _scope_tape_info(project_driver, session_id, tape)
    _upsert_tape!(db, tape_info)

    tape_record_ord = 0
    commit_ord = 0
    last_commit_file = nothing
    last_commit_line = nothing
    last_record_file = nothing
    last_record_line = nothing
    last_record_hash = nothing

    Kernel.scan_tape_records_filtered(
        tape;
        line_filter = (line, ctx) -> true,
        json_filter = (obj, ctx) -> true,
        on_record = function (raw, ctx)
            tape_record_ord += 1
            rec_hash = _record_hash(raw)
            last_record_file = ctx.file
            last_record_line = ctx.line_no
            last_record_hash = rec_hash

            if verify_prefix && tape_record_ord <= start_tape_record_ord
                _verify_indexed_tape_record_prefix!(
                    db,
                    tape_info.tape_uid,
                    tape_record_ord,
                    raw,
                    ctx.file,
                    ctx.line_no;
                    record_hash = rec_hash,
                )
            else
                _insert_tape_record!(
                    db,
                    tape_info.tape_uid,
                    tape_record_ord,
                    raw,
                    ctx.file,
                    ctx.line_no;
                    record_hash = rec_hash,
                )
            end

            _record_type(raw) == "commit" || return nothing
            commit_ord += 1

            commit = Kernel._parse_commit(raw)
            last_commit_file = ctx.file
            last_commit_line = ctx.line_no

            if verify_prefix && commit_ord <= start_commit_ord
                _verify_indexed_commit_prefix!(
                    db,
                    session_id,
                    commit_ord,
                    commit,
                    tape_record_ord,
                    ctx.file,
                    ctx.line_no,
                )
                return nothing
            end

            _insert_commit_and_scopes!(
                db,
                session_id,
                commit_ord,
                commit,
                tape_record_ord,
                ctx.file,
                ctx.line_no,
            )
            return nothing
        end,
    )

    if verify_prefix && tape_record_ord < start_tape_record_ord
        throw(_SQLiteIndexDriftError(
            "SQLite metadata index drift: scope tape `$(tape_info.tape_uid)` has fewer records than indexed state."
        ))
    end

    if verify_prefix && commit_ord < start_commit_ord
        throw(_SQLiteIndexDriftError(
            "SQLite metadata index drift: session `$(session_id)` tape has fewer commits than indexed state."
        ))
    end

    return (
        last_indexed_commit_ord = commit_ord,
        last_indexed_tape_record_ord = tape_record_ord,
        last_tape_file = last_commit_file,
        last_tape_line_no = last_commit_line,
        tape_uid = tape_info.tape_uid,
        last_record_file = last_record_file,
        last_record_line_no = last_record_line,
        last_record_hash = last_record_hash,
    )
end

function _insert_commit_and_scopes!(
        db::SQLite.DB,
        session_id::String,
        commit_ord::Int,
        commit::Kernel.CaptureTree,
        tape_record_ord::Int,
        tape_file::String,
        tape_line_no::Int,
    )
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
        commit.label,
        _string_or_nothing(get(commit.metadata, "timestamp", nothing)),
        tape_record_ord,
        tape_file,
        tape_line_no,
    ))

    for (scope_ord, scope) in enumerate(Kernel.ScopeSnapshot[s for s in commit.snapshots if s isa Kernel.ScopeSnapshot])
        _index_scope!(db, session_id, commit_uid, commit_ord, scope_ord, scope)
    end
    return nothing
end

function _verify_indexed_commit_prefix!(
        db::SQLite.DB,
        session_id::String,
        commit_ord::Int,
        commit::Kernel.CaptureTree,
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
       row[:commit_label] != commit.label ||
       row[:tape_record_ord] != tape_record_ord ||
       row[:tape_file] != tape_file ||
       row[:tape_line_no] != tape_line_no
        throw(_SQLiteIndexDriftError(
            "SQLite metadata index drift: indexed commit prefix mismatch for session `$(session_id)` commit_ord=$(commit_ord)."
        ))
    end
    return nothing
end

function _scope_tape_info(
        project_driver::Kernel.SimuleosProject,
        session_id::String,
        tape::Kernel.TapeIO,
    )
    rel = _path_rel_to_project(project_driver, tape.path)
    return (
        tape_uid = _scope_tape_uid(project_driver, tape),
        subsystem_id = _SQLITE_INDEX_SCOPE_SUBSYSTEM_ID,
        logical_owner_id = session_id,
        tape_role = "main",
        tape_path = abspath(tape.path),
        tape_relpath = rel,
        exists_on_disk = (ispath(tape.path) ? 1 : 0),
    )
end

function _scope_tape_uid(project_driver::Kernel.SimuleosProject, tape::Kernel.TapeIO)::String
    rel = _path_rel_to_project(project_driver, tape.path)
    return string(_SQLITE_INDEX_SCOPE_SUBSYSTEM_ID, ":", rel)
end

function _path_rel_to_project(project_driver::Kernel.SimuleosProject, path::String)::String
    rel = relpath(abspath(path), project_driver.root_path)
    return replace(rel, '\\' => '/')
end

function _upsert_tape!(db::SQLite.DB, tape_info)
    _sqlite_exec(db, """
        INSERT INTO tapes (
            tape_uid, subsystem_id, logical_owner_id, tape_role, tape_path, tape_relpath,
            exists_on_disk, last_seen_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(tape_uid) DO UPDATE SET
            subsystem_id = excluded.subsystem_id,
            logical_owner_id = excluded.logical_owner_id,
            tape_role = excluded.tape_role,
            tape_path = excluded.tape_path,
            tape_relpath = excluded.tape_relpath,
            exists_on_disk = excluded.exists_on_disk,
            last_seen_at = excluded.last_seen_at
    """, (
        tape_info.tape_uid,
        tape_info.subsystem_id,
        tape_info.logical_owner_id,
        tape_info.tape_role,
        tape_info.tape_path,
        tape_info.tape_relpath,
        Int(tape_info.exists_on_disk),
        string(Dates.now()),
    ))
    return nothing
end

function _delete_scope_tape_catalog!(db::SQLite.DB, session_id::String)
    _sqlite_exec(db,
        "DELETE FROM tapes WHERE subsystem_id = ? AND logical_owner_id = ?",
        (_SQLITE_INDEX_SCOPE_SUBSYSTEM_ID, session_id),
    )
    return nothing
end

function _insert_tape_record!(
        db::SQLite.DB,
        tape_uid::String,
        record_ord::Int,
        raw::AbstractDict,
        file_path::String,
        line_no::Int;
        record_hash::Union{Nothing, String} = nothing,
    )
    rec_type = _record_type(raw)
    # Default mapping: generic tape record type and subsystem-kind are the same.
    # Keep the separate column populated anyway so adapters can diverge later
    # without backfilling old rows or changing the public `v_tape_records` shape.
    subsystem_kind = rec_type
    _sqlite_exec(db, """
        INSERT INTO tape_records (
            tape_uid, record_ord, record_type, writer, timetag, file_path, line_no,
            record_hash, subsystem_record_kind
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    """, (
        tape_uid,
        record_ord,
        rec_type,
        _record_writer(raw),
        _record_timetag(raw),
        file_path,
        line_no,
        record_hash,
        subsystem_kind,
    ))
    return nothing
end

function _verify_indexed_tape_record_prefix!(
        db::SQLite.DB,
        tape_uid::String,
        record_ord::Int,
        raw::AbstractDict,
        file_path::String,
        line_no::Int;
        record_hash::Union{Nothing, String} = nothing,
    )
    row = _sqlite_one_or_nothing(db, """
        SELECT tape_uid, record_ord, record_type, writer, timetag, file_path, line_no, record_hash, subsystem_record_kind
        FROM tape_records
        WHERE tape_uid = ? AND record_ord = ?
    """, (tape_uid, record_ord))
    isnothing(row) && throw(_SQLiteIndexDriftError(
        "SQLite metadata index drift: missing indexed tape-record prefix for tape `$(tape_uid)` record_ord=$(record_ord)."
    ))

    rec_type = _record_type(raw)
    row_tape_uid = String(row[:tape_uid])
    row_record_ord = Int(row[:record_ord])
    row_record_type = _sqlite_nullable_text(row[:record_type])
    row_writer = _sqlite_nullable_text(row[:writer])
    row_timetag = _sqlite_nullable_text(row[:timetag])
    row_file_path = String(row[:file_path])
    row_line_no = Int(row[:line_no])
    row_record_hash = _sqlite_nullable_text(row[:record_hash])
    row_subsystem_kind = _sqlite_nullable_text(row[:subsystem_record_kind])

    expected_subsystem_kind = rec_type  # See `_insert_tape_record!` default mapping.

    if row_tape_uid != tape_uid ||
       row_record_ord != record_ord ||
       row_record_type != rec_type ||
       row_writer != _record_writer(raw) ||
       row_timetag != _record_timetag(raw) ||
       row_file_path != file_path ||
       row_line_no != line_no ||
       row_record_hash != record_hash ||
       row_subsystem_kind != expected_subsystem_kind
        throw(_SQLiteIndexDriftError(
            "SQLite metadata index drift: indexed tape-record prefix mismatch for tape `$(tape_uid)` record_ord=$(record_ord)."
        ))
    end
    return nothing
end

function _update_scope_tape_index_state!(
        db::SQLite.DB,
        project_driver::Kernel.SimuleosProject,
        session_id::String,
        stats;
        refresh_mode::String,
        drift_status::String = "ok",
    )
    tape_uid = hasproperty(stats, :tape_uid) ?
        String(getproperty(stats, :tape_uid)) :
        _scope_tape_uid(project_driver, Kernel.TapeIO(Kernel.tape_path(project_driver.simuleos_dir, session_id)))

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
        tape_uid,
        _SQLITE_INDEX_SCOPE_SUBSYSTEM_ID,
        Int(stats.last_indexed_tape_record_ord),
        _string_or_nothing(getproperty(stats, :last_record_file)),
        _int_or_nothing(getproperty(stats, :last_record_line_no)),
        _string_or_nothing(getproperty(stats, :last_record_hash)),
        string(Dates.now()),
        refresh_mode,
        drift_status,
    ))
    return nothing
end
