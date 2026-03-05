# ============================================================
# classsystem/catalog.jl — Built-in semantic class catalog
# ============================================================

const CLASS_SPEC_SRC_CODEBASE = "src.codebase@v1"
const CLASS_SPEC_SRC_RUNTIME_HOST = "src.runtime_host@v1"
const CLASS_SPEC_SRC_EXECUTION_SITE = "src.execution_site@v1"
const CLASS_SPEC_SRC_NAMESPACE_BINDINGS = "src.namespace_bindings@v1"
const CLASS_SPEC_SRC_SETTINGS_ACCESS = "src.settings_access@v1"
const CLASS_SPEC_SRC_SESSION_STATE = "src.session_state@v1"
const CLASS_SPEC_SNAP_SCOPE = "snap.scope@v1"
const CLASS_SPEC_SNAP_CONTEXT = "snap.context@v1"
const CLASS_SPEC_SNAP_SHARED = "snap.shared@v1"
const CLASS_SPEC_REC_CAPTURE_COMMIT = "rec.capture_commit@v1"
const CLASS_SPEC_REC_REF = "rec.ref@v1"

_class_id(spec::AbstractString)::String = class_parse(spec).id
_class_version(spec::AbstractString)::Int = class_parse(spec).version

function _class_register_builtin!(spec::SimuleosClassSpec)::SimuleosClassSpec
    if class_exists(spec.id, spec.version)
        return class_spec(spec.id, spec.version)
    end
    return class_register!(spec)
end

function _classsystem_builtin_specs()::Vector{SimuleosClassSpec}
    return SimuleosClassSpec[
        SimuleosClassSpec(
            _class_id(CLASS_SPEC_SRC_CODEBASE),
            _class_version(CLASS_SPEC_SRC_CODEBASE);
            fields = [
                (name = "git_commit", semantic_type = "string", required = false),
                (name = "git_branch", semantic_type = "string", required = false),
                (name = "git_dirty", semantic_type = "bool", required = false),
                (name = "git_describe", semantic_type = "string", required = false),
            ],
        ),
        SimuleosClassSpec(
            _class_id(CLASS_SPEC_SRC_RUNTIME_HOST),
            _class_version(CLASS_SPEC_SRC_RUNTIME_HOST);
            fields = [
                (name = "julia_version", semantic_type = "string", required = false),
                (name = "hostname", semantic_type = "string", required = false),
                (name = "os", semantic_type = "string", required = false),
                (name = "word_size", semantic_type = "int", required = false),
                (name = "threads", semantic_type = "int", required = false),
                (name = "timestamp", semantic_type = "string", required = false),
            ],
        ),
        SimuleosClassSpec(
            _class_id(CLASS_SPEC_SRC_EXECUTION_SITE),
            _class_version(CLASS_SPEC_SRC_EXECUTION_SITE);
            fields = [
                (name = "src_file", semantic_type = "string", required = false),
                (name = "src_line", semantic_type = "int", required = false),
                (name = "threadid", semantic_type = "int", required = false),
                (name = "timestamp", semantic_type = "string", required = false),
            ],
        ),
        SimuleosClassSpec(
            _class_id(CLASS_SPEC_SRC_NAMESPACE_BINDINGS),
            _class_version(CLASS_SPEC_SRC_NAMESPACE_BINDINGS);
            fields = [
                (name = "labels", semantic_type = "vector[string]", required = false),
                (name = "variables", semantic_type = "map[symbol,binding]", required = false),
                (name = "metadata", semantic_type = "map[symbol,any]", required = false),
            ],
        ),
        SimuleosClassSpec(
            _class_id(CLASS_SPEC_SRC_SETTINGS_ACCESS),
            _class_version(CLASS_SPEC_SRC_SETTINGS_ACCESS);
            fields = [
                (name = "accessed", semantic_type = "map[string,any]", required = false),
                (name = "timestamp", semantic_type = "string", required = false),
            ],
        ),
        SimuleosClassSpec(
            _class_id(CLASS_SPEC_SRC_SESSION_STATE),
            _class_version(CLASS_SPEC_SRC_SESSION_STATE);
            fields = [
                (name = "session_id", semantic_type = "string", required = false),
                (name = "labels", semantic_type = "vector[string]", required = false),
                (name = "meta", semantic_type = "map[string,any]", required = false),
            ],
        ),
        SimuleosClassSpec(
            _class_id(CLASS_SPEC_SNAP_SCOPE),
            _class_version(CLASS_SPEC_SNAP_SCOPE);
            compose_from = [
                CLASS_SPEC_SRC_NAMESPACE_BINDINGS,
                CLASS_SPEC_SRC_EXECUTION_SITE,
            ],
            fields = [
                (name = "labels", semantic_type = "vector[string]", required = false),
                (name = "variables", semantic_type = "map[symbol,binding]", required = false),
                (name = "metadata", semantic_type = "map[symbol,any]", required = false),
            ],
        ),
        SimuleosClassSpec(
            _class_id(CLASS_SPEC_SNAP_CONTEXT),
            _class_version(CLASS_SPEC_SNAP_CONTEXT);
            compose_from = [
                CLASS_SPEC_SRC_SETTINGS_ACCESS,
                CLASS_SPEC_SRC_CODEBASE,
                CLASS_SPEC_SRC_RUNTIME_HOST,
                CLASS_SPEC_SRC_EXECUTION_SITE,
                CLASS_SPEC_SRC_SESSION_STATE,
            ],
            fields = [
                (name = "settings", semantic_type = "src.settings_access", required = false),
                (name = "source", semantic_type = "src.codebase", required = false),
                (name = "environment", semantic_type = "src.runtime_host", required = false),
                (name = "execution", semantic_type = "src.execution_site", required = false),
                (name = "session_id", semantic_type = "string", required = false),
                (name = "labels", semantic_type = "vector[string]", required = false),
            ],
        ),
        SimuleosClassSpec(
            _class_id(CLASS_SPEC_SNAP_SHARED),
            _class_version(CLASS_SPEC_SNAP_SHARED);
            compose_from = [
                CLASS_SPEC_SRC_NAMESPACE_BINDINGS,
                CLASS_SPEC_SRC_EXECUTION_SITE,
            ],
            fields = [
                (name = "labels", semantic_type = "vector[string]", required = false),
                (name = "variables", semantic_type = "map[symbol,binding]", required = false),
                (name = "metadata", semantic_type = "map[symbol,any]", required = false),
                (name = "shared_key", semantic_type = "string", required = false),
            ],
        ),
        SimuleosClassSpec(
            _class_id(CLASS_SPEC_REC_CAPTURE_COMMIT),
            _class_version(CLASS_SPEC_REC_CAPTURE_COMMIT);
            compose_from = [CLASS_SPEC_SNAP_SCOPE],
            fields = [
                (name = "metadata", semantic_type = "map[string,any]", required = false),
                (name = "scopes", semantic_type = "vector[snap.scope]", required = false),
                (name = "commit_label", semantic_type = "string", required = false),
            ],
        ),
        SimuleosClassSpec(
            _class_id(CLASS_SPEC_REC_REF),
            _class_version(CLASS_SPEC_REC_REF);
            fields = [
                (name = "record_hash", semantic_type = "string", required = false),
                (name = "record_short", semantic_type = "string", required = false),
                (name = "writer", semantic_type = "string", required = false),
                (name = "timetag", semantic_type = "string", required = false),
                (name = "payload", semantic_type = "any", required = false),
            ],
        ),
    ]
end

"""
    classsystem_bootstrap!() -> Nothing

Register built-in Simuleos semantic classes in dependency order.
Idempotent.
"""
function classsystem_bootstrap!()::Nothing
    for spec in _classsystem_builtin_specs()
        _class_register_builtin!(spec)
    end
    return nothing
end
