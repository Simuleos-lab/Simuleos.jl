# ============================================================
# capture/serialization.jl — Serialize DataClasses to records
# ============================================================

"""
    serialize_capture(c::SimuleosDataClass) -> Dict{String, Any}

Convert one semantic runtime DataClass to a class-stamped raw record.
"""
function serialize_capture(c::SimuleosDataClass)::Dict{String, Any}
    error("No serializer registered for DataClass `$(typeof(c))`.")
end

serialize_capture(c::SrcSettingsAccessV1)::Dict{String, Any} = encode_src_settings_access_record(c)
serialize_capture(c::SrcCodebaseV1)::Dict{String, Any} = encode_src_codebase_record(c)
serialize_capture(c::SrcRuntimeHostV1)::Dict{String, Any} = encode_src_runtime_host_record(c)
serialize_capture(c::SrcExecutionSiteV1)::Dict{String, Any} = encode_src_execution_site_record(c)
serialize_capture(c::SrcNamespaceBindingsV1)::Dict{String, Any} = encode_src_namespace_bindings_record(c)
serialize_capture(c::SrcSessionStateV1)::Dict{String, Any} = encode_src_session_state_record(c)
serialize_capture(c::SnapScopeV1)::Dict{String, Any} = encode_snap_scope_record(c)
serialize_capture(c::SnapSharedV1)::Dict{String, Any} = encode_snap_shared_record(c)
serialize_capture(c::SnapContextV1)::Dict{String, Any} = encode_snap_context_record(c)
serialize_capture(c::RecCaptureCommitV1)::Dict{String, Any} = encode_rec_capture_commit_record(c)
serialize_capture(c::RecRefV1)::Dict{String, Any} = encode_rec_ref_record(c)
