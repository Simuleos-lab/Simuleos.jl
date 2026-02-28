# ============================================================
# classsystem/catalog.jl — Built-in semantic class catalog
# ============================================================

function _class_register_builtin!(spec::SimuleosClassSpec)::SimuleosClassSpec
    if class_exists(spec.id, spec.version)
        return class_spec(spec.id, spec.version)
    end
    return class_register!(spec)
end

function _classsystem_builtin_specs()::Vector{SimuleosClassSpec}
    return SimuleosClassSpec[
        SimuleosClassSpec(
            "src.codebase",
            1;
            fields = [
                (name = "git_commit", semantic_type = "string", required = false),
                (name = "git_branch", semantic_type = "string", required = false),
                (name = "git_dirty", semantic_type = "bool", required = false),
                (name = "git_describe", semantic_type = "string", required = false),
            ],
        ),
        SimuleosClassSpec(
            "src.runtime_host",
            1;
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
            "src.execution_site",
            1;
            fields = [
                (name = "src_file", semantic_type = "string", required = false),
                (name = "src_line", semantic_type = "int", required = false),
                (name = "threadid", semantic_type = "int", required = false),
                (name = "timestamp", semantic_type = "string", required = false),
            ],
        ),
        SimuleosClassSpec(
            "src.namespace_bindings",
            1;
            fields = [
                (name = "labels", semantic_type = "vector[string]", required = false),
                (name = "variables", semantic_type = "map[symbol,binding]", required = false),
                (name = "metadata", semantic_type = "map[symbol,any]", required = false),
            ],
        ),
        SimuleosClassSpec(
            "src.settings_access",
            1;
            fields = [
                (name = "accessed", semantic_type = "map[string,any]", required = false),
                (name = "timestamp", semantic_type = "string", required = false),
            ],
        ),
        SimuleosClassSpec(
            "src.session_state",
            1;
            fields = [
                (name = "session_id", semantic_type = "string", required = false),
                (name = "labels", semantic_type = "vector[string]", required = false),
                (name = "meta", semantic_type = "map[string,any]", required = false),
            ],
        ),
        SimuleosClassSpec(
            "snap.scope",
            1;
            compose_from = [
                "src.namespace_bindings@v1",
                "src.execution_site@v1",
            ],
            fields = [
                (name = "labels", semantic_type = "vector[string]", required = false),
                (name = "variables", semantic_type = "map[symbol,binding]", required = false),
                (name = "metadata", semantic_type = "map[symbol,any]", required = false),
            ],
        ),
        SimuleosClassSpec(
            "snap.context",
            1;
            compose_from = [
                "src.settings_access@v1",
                "src.codebase@v1",
                "src.runtime_host@v1",
                "src.execution_site@v1",
                "src.session_state@v1",
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
            "snap.shared",
            1;
            compose_from = [
                "src.namespace_bindings@v1",
                "src.execution_site@v1",
            ],
            fields = [
                (name = "labels", semantic_type = "vector[string]", required = false),
                (name = "variables", semantic_type = "map[symbol,binding]", required = false),
                (name = "metadata", semantic_type = "map[symbol,any]", required = false),
                (name = "shared_key", semantic_type = "string", required = false),
            ],
        ),
        SimuleosClassSpec(
            "rec.capture_commit",
            1;
            compose_from = ["snap.scope@v1"],
            fields = [
                (name = "type", semantic_type = "string", required = false),
                (name = "metadata", semantic_type = "map[string,any]", required = false),
                (name = "scopes", semantic_type = "vector[snap.scope]", required = false),
                (name = "commit_label", semantic_type = "string", required = false),
            ],
        ),
        SimuleosClassSpec(
            "rec.ref",
            1;
            fields = [
                (name = "type", semantic_type = "string", required = false),
                (name = "record_hash", semantic_type = "string", required = false),
                (name = "record_short", semantic_type = "string", required = false),
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
