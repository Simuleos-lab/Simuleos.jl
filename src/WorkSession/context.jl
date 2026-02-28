# ============================================================
# WorkSession/context.jl — Context capture and resolve
#
# Composes partial captures (settings, source, environment,
# execution) into a single provenance tree and writes it
# as a content-addressed generic record.
# ============================================================

"""
    _flush_settings_access_log!(ws) -> Dict{String, Any}

Return the current settings access log and replace it with a fresh empty dict.
Returns an empty dict if tracking is off or the log is nothing.
"""
function _flush_settings_access_log!(ws::_Kernel.WorkSession)::Dict{String, Any}
    log = ws.settings_access_log
    if isnothing(log)
        return Dict{String, Any}()
    end
    result = copy(log)
    empty!(log)
    return result
end

"""
    context_capture!(ws, proj) -> RecordRef

Flush the settings access log, assemble a context tree from the
session's source/environment captures plus a fresh execution capture,
write it as a generic record to the session tape, and return its ref.
"""
function context_capture!(
        ws::_Kernel.WorkSession,
        proj::_Kernel.SimuleosProject,
    )::_Kernel.RecordRef

    _Kernel._require_context_class_registration!()

    # Flush settings access log
    settings_accessed = _flush_settings_access_log!(ws)

    # Build context tree from partial captures
    tree = Dict{String, Any}()

    # Settings
    if !isempty(settings_accessed)
        sc = _Kernel.SettingsSnapshot(settings_accessed, string(Dates.now()))
        tree["settings"] = _Kernel.serialize_capture(sc)
    end

    # Source (captured once at session init)
    if !isnothing(ws.source_capture)
        tree["source"] = _Kernel.serialize_capture(ws.source_capture)
    end

    # Environment (captured once at session init)
    if !isnothing(ws.environment_capture)
        tree["environment"] = _Kernel.serialize_capture(ws.environment_capture)
    end

    # Execution (fresh per capture)
    exec = _Kernel.capture_execution()
    tree["execution"] = _Kernel.serialize_capture(exec)

    # Session metadata
    tree["session_id"] = string(ws.session_id)
    tree["labels"] = copy(ws.labels)

    payload = _Kernel.encode_snap_context_record(tree)

    # Write to tape
    tape = _Kernel.TapeIO(_Kernel.tape_path(proj, ws.session_id))
    return _Kernel.record_write(tape, payload)
end

"""
    context_resolve(proj, ws, ref_str) -> Union{Dict{String, Any}, Nothing}

Look up a context record by hash or short prefix on the session tape.
"""
function context_resolve(
        proj::_Kernel.SimuleosProject,
        ws::_Kernel.WorkSession,
        ref_str::String,
    )::Union{Dict{String, Any}, Nothing}
    tape = _Kernel.TapeIO(_Kernel.tape_path(proj, ws.session_id))
    payload = _Kernel.record_resolve(tape, ref_str)
    isnothing(payload) && return nothing
    payload isa AbstractDict || error("Expected context payload to be a dict-like record.")
    return _Kernel.decode_snap_context_record(payload)
end
