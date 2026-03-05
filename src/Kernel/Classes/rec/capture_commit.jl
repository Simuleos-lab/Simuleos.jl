# ============================================================
# Classes/rec/capture_commit.jl — `rec.capture_commit` class semantics
# ============================================================

const _CAPTURE_COMMIT_CLASS_SPEC = CLASS_SPEC_REC_CAPTURE_COMMIT
const _CAPTURE_COMMIT_CLASS_ID = _class_id(_CAPTURE_COMMIT_CLASS_SPEC)
const _CAPTURE_COMMIT_CLASS_VERSION = _class_version(_CAPTURE_COMMIT_CLASS_SPEC)

function _require_capture_commit_class_registration!()::Nothing
    class_require!(_CAPTURE_COMMIT_CLASS_ID, _CAPTURE_COMMIT_CLASS_VERSION)
    return nothing
end

function encode_rec_capture_commit_record(commit::RecCaptureCommitV1)::Dict{String, Any}
    _require_capture_commit_class_registration!()

    scopes = SnapScopeV1[s for s in commit.capture.snapshots if s isa SnapScopeV1]
    out = _stamp_class_record(Dict{String, Any}(
        "metadata" => copy(commit.metadata),
        "scopes" => Dict{String, Any}[encode_snap_scope_record(scope) for scope in scopes],
    ), _CAPTURE_COMMIT_CLASS_ID, _CAPTURE_COMMIT_CLASS_VERSION)
    if !isempty(commit.label)
        out["commit_label"] = commit.label
    end
    return out
end

function _decode_rec_capture_commit_record_by_class(
        cls::SimuleosClassTag,
        data::AbstractDict,
    )::RecCaptureCommitV1
    error("No rec.capture_commit decoder registered for class `$(class_spec_string(cls))`.")
end

function _decode_rec_capture_commit_record_by_class(
        ::SimuleosClassTag{Symbol(_CAPTURE_COMMIT_CLASS_ID), _CAPTURE_COMMIT_CLASS_VERSION},
        data::AbstractDict,
    )::RecCaptureCommitV1
    metadata = Dict{String, Any}()
    if haskey(data, "metadata") && data["metadata"] isa AbstractDict
        metadata = _string_keys(data["metadata"])
    end

    scopes = SnapScopeV1[]
    for scope_raw in get(data, "scopes", Any[])
        scope_raw isa AbstractDict || continue
        push!(scopes, decode_snap_scope_record(scope_raw))
    end

    label = string(get(data, "commit_label", ""))
    capture = CaptureTree(label, SimuleosDataClass[s for s in scopes], CaptureTree[], Dict{String, Any}())

    return RecCaptureCommitV1(;
        label = label,
        capture = capture,
        metadata = metadata,
    )
end

function decode_rec_capture_commit_record(data::AbstractDict)::RecCaptureCommitV1
    cls = _record_class_tag(
        data;
        default_id = _CAPTURE_COMMIT_CLASS_ID,
        default_version = _CAPTURE_COMMIT_CLASS_VERSION,
        payload_name = "rec.capture_commit",
    )
    return _decode_rec_capture_commit_record_by_class(cls, data)
end
