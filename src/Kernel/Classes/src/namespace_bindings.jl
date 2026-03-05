# ============================================================
# Classes/src/namespace_bindings.jl — `src.namespace_bindings` class semantics
# ============================================================

const _SRC_NAMESPACE_BINDINGS_CLASS_SPEC = CLASS_SPEC_SRC_NAMESPACE_BINDINGS
const _SRC_NAMESPACE_BINDINGS_CLASS_ID = _class_id(_SRC_NAMESPACE_BINDINGS_CLASS_SPEC)
const _SRC_NAMESPACE_BINDINGS_CLASS_VERSION = _class_version(_SRC_NAMESPACE_BINDINGS_CLASS_SPEC)

function _require_src_namespace_bindings_class_registration!()::Nothing
    class_require!(_SRC_NAMESPACE_BINDINGS_CLASS_ID, _SRC_NAMESPACE_BINDINGS_CLASS_VERSION)
    return nothing
end

function encode_src_namespace_bindings_record(data::AbstractDict)::Dict{String, Any}
    _require_src_namespace_bindings_class_registration!()
    return _stamp_class_record(data, _SRC_NAMESPACE_BINDINGS_CLASS_ID, _SRC_NAMESPACE_BINDINGS_CLASS_VERSION)
end

function encode_src_namespace_bindings_record(scope::SrcNamespaceBindingsV1)::Dict{String, Any}
    return encode_src_namespace_bindings_record(Dict{String, Any}(
        "labels" => copy(scope.labels),
        "variables" => _encode_scope_variables_record(scope.variables),
        "metadata" => Dict{String, Any}(string(k) => v for (k, v) in scope.metadata),
    ))
end

function _decode_namespace_binding_labels(data::AbstractDict)::Vector{String}
    labels = String[]
    for raw in get(data, "labels", Any[])
        label = string(raw)
        label in labels || push!(labels, label)
    end
    return labels
end

function _decode_namespace_binding_variables(data::AbstractDict)::Dict{Symbol, ScopeVariable}
    vars = Dict{Symbol, ScopeVariable}()
    vars_raw = get(data, "variables", Dict{String, Any}())
    if vars_raw isa AbstractDict
        for (name, payload) in vars_raw
            name_s = string(name)
            vars[Symbol(name_s)] = decode_snap_scope_variable_record(name_s, payload)
        end
    end
    return vars
end

function _decode_namespace_binding_metadata(data::AbstractDict)::Dict{Symbol, Any}
    metadata = Dict{Symbol, Any}()
    meta_raw = get(data, "metadata", Dict{String, Any}())
    if meta_raw isa AbstractDict
        for (k, v) in meta_raw
            metadata[Symbol(string(k))] = v
        end
    end
    return metadata
end

function _decode_src_namespace_bindings_record_by_class(
        cls::SimuleosClassTag,
        data::AbstractDict,
    )::SrcNamespaceBindingsV1
    error("No src.namespace_bindings decoder registered for class `$(class_spec_string(cls))`.")
end

function _decode_src_namespace_bindings_record_by_class(
        ::SimuleosClassTag{Symbol(_SRC_NAMESPACE_BINDINGS_CLASS_ID), _SRC_NAMESPACE_BINDINGS_CLASS_VERSION},
        data::AbstractDict,
    )::SrcNamespaceBindingsV1
    labels = _decode_namespace_binding_labels(data)
    variables = _decode_namespace_binding_variables(data)
    metadata = _decode_namespace_binding_metadata(data)
    return SrcNamespaceBindingsV1(labels, variables, metadata)
end

function decode_src_namespace_bindings_record(data::AbstractDict)::SrcNamespaceBindingsV1
    cls = _record_class_tag(
        data;
        default_id = _SRC_NAMESPACE_BINDINGS_CLASS_ID,
        default_version = _SRC_NAMESPACE_BINDINGS_CLASS_VERSION,
        payload_name = "src.namespace_bindings",
    )
    return _decode_src_namespace_bindings_record_by_class(cls, data)
end
