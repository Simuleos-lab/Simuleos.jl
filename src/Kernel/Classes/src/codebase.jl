# ============================================================
# Classes/src/codebase.jl — `src.codebase` class semantics
# ============================================================

const _SRC_CODEBASE_CLASS_SPEC = CLASS_SPEC_SRC_CODEBASE
const _SRC_CODEBASE_CLASS_ID = _class_id(_SRC_CODEBASE_CLASS_SPEC)
const _SRC_CODEBASE_CLASS_VERSION = _class_version(_SRC_CODEBASE_CLASS_SPEC)

function _require_src_codebase_class_registration!()::Nothing
    class_require!(_SRC_CODEBASE_CLASS_ID, _SRC_CODEBASE_CLASS_VERSION)
    return nothing
end

function encode_src_codebase_record(data::AbstractDict)::Dict{String, Any}
    _require_src_codebase_class_registration!()
    return _stamp_class_record(data, _SRC_CODEBASE_CLASS_ID, _SRC_CODEBASE_CLASS_VERSION)
end

function encode_src_codebase_record(s::SrcCodebaseV1)::Dict{String, Any}
    return encode_src_codebase_record(Dict{String, Any}(
        "git_commit" => s.git_commit,
        "git_branch" => s.git_branch,
        "git_dirty" => s.git_dirty,
        "git_describe" => s.git_describe,
    ))
end

function _decode_src_codebase_record_by_class(
        cls::SimuleosClassTag,
        data::AbstractDict,
    )::SrcCodebaseV1
    error("No src.codebase decoder registered for class `$(class_spec_string(cls))`.")
end

function _decode_src_codebase_record_by_class(
        ::SimuleosClassTag{Symbol(_SRC_CODEBASE_CLASS_ID), _SRC_CODEBASE_CLASS_VERSION},
        data::AbstractDict,
    )::SrcCodebaseV1
    git_commit = string(get(data, "git_commit", ""))
    git_branch = string(get(data, "git_branch", ""))
    git_dirty = Bool(get(data, "git_dirty", false))
    git_describe = string(get(data, "git_describe", ""))
    return SrcCodebaseV1(git_commit, git_branch, git_dirty, git_describe)
end

function decode_src_codebase_record(data::AbstractDict)::SrcCodebaseV1
    cls = _record_class_tag(
        data;
        default_id = _SRC_CODEBASE_CLASS_ID,
        default_version = _SRC_CODEBASE_CLASS_VERSION,
        payload_name = "src.codebase",
    )
    return _decode_src_codebase_record_by_class(cls, data)
end
