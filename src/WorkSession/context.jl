# ============================================================
# WorkSession/context.jl — Context capture and resolve
#
# Composes partial captures (settings, source, environment,
# execution) into a single provenance tree and writes it
# as a content-addressed `rec.ref` envelope.
# ============================================================

"""
    _flush_settings_access_log!(ws) -> Dict{String, Any}

Return the current settings access log and replace it with a fresh empty dict.
Returns an empty dict if tracking is off or the log is nothing.
"""
function _flush_settings_access_log!(ws::_Krn.WorkSession)::Dict{String, Any}
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
    write it as a `rec.ref` envelope to the session tape, and return its ref.
"""
function context_capture!(
        ws::_Krn.WorkSession,
        proj::_Krn.SimuleosProject,
    )::_Krn.RecordRef

    _Krn._require_context_class_registration!()

    # Flush settings access log
    settings_accessed = _flush_settings_access_log!(ws)

    settings = isempty(settings_accessed) ? nothing :
        _Krn.SrcSettingsAccessV1(settings_accessed, string(Dates.now()))

    context = _Krn.SnapContextV1(;
        settings = settings,
        source = ws.source_capture,
        environment = ws.environment_capture,
        execution = _Krn.capture_execution(),
        session_id = string(ws.session_id),
        labels = copy(ws.labels),
    )

    payload = _Krn.encode_snap_context_record(context)

    # Write to tape
    tape = _Krn.session_tape(proj, ws.session_id)
    return _Krn.record_write(tape, payload)
end

"""
    context_resolve(proj, ws, ref_str) -> Union{_Krn.SnapContextV1, Nothing}

Look up a context record by hash or short prefix on the session tape.
"""
function context_resolve(
        proj::_Krn.SimuleosProject,
        ws::_Krn.WorkSession,
        ref_str::String,
    )::Union{_Krn.SnapContextV1, Nothing}
    tape = _Krn.session_tape(proj, ws.session_id)
    payload = _Krn.record_resolve(tape, ref_str)
    isnothing(payload) && return nothing
    payload isa AbstractDict || error("Expected context payload to be a dict-like record.")
    return _Krn.decode_snap_context_record(payload)
end
