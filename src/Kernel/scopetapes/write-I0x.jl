# ScopeTapes write primitives (all I0x)
# Blob/lite classification happens at serialization time.

const MAX_TAPE_SIZE_BYTES = 200_000_000  # 200 MB threshold for tape file warnings

"""
    _should_ignore_var(name, val, scope_label, rules) -> Bool

Check if a variable should be ignored using base type filtering plus rules.
- Base filtering always excludes `Module` and `Function` values.
- Rules use simignore shape (`:regex`, optional `:scope`, `:action`).
- Last matching rule wins.
"""
function _should_ignore_var(
        name::Symbol, val::Any,
        scope_label::String, rules::Vector
    )::Bool
    val isa Module && return true
    val isa Function && return true

    name_str = string(name)
    last_rule = nothing
    for rule in rules
        occursin(rule[:regex], name_str) || continue
        rule_scope = get(rule, :scope, nothing)
        isnothing(rule_scope) || rule_scope == scope_label || continue
        last_rule = rule
    end

    isnothing(last_rule) && return false
    return get(last_rule, :action, nothing) == :exclude
end

function _get_type_string(val)::String
    first(string(typeof(val)), 25)
end

function _compute_blob_refs(ctx::CaptureContext, root_dir::String)::Dict{Symbol, String}
    refs = Dict{Symbol, String}()
    for (name, sv) in ctx.scope.variables
        if name in ctx.blob_set
            ref = blob_write(root_dir, sv.val, sv.val)
            refs[name] = ref.hash
        end
    end
    refs
end

function _write_variable_json(io::IO, name::Symbol, sv::ScopeVariable, blob_refs::Dict{Symbol, String})
    src_type = _get_type_string(sv.val)

    print(io, "{\"src_type\":")
    _write_json(io, src_type)
    print(io, ",\"src\":")
    _write_json(io, sv.src)

    if haskey(blob_refs, name)
        print(io, ",\"blob_ref\":")
        _write_json(io, blob_refs[name])
    elseif _is_lite(sv.val)
        print(io, ",\"value\":")
        _write_json(io, _liteify(sv.val))
    end

    print(io, "}")
end

function _write_capture_json(io::IO, ctx::CaptureContext, blob_refs::Dict{Symbol, String})
    scope = ctx.scope

    print(io, "{\"label\":")
    _write_json(io, isempty(scope.labels) ? "" : scope.labels[1])
    print(io, ",\"timestamp\":")
    _write_json(io, ctx.timestamp)
    print(io, ",\"variables\":{")
    first_var = true
    for (name, sv) in scope.variables
        first_var || print(io, ",")
        first_var = false
        _write_json(io, string(name))
        print(io, ":")
        _write_variable_json(io, name, sv, blob_refs)
    end
    print(io, "}")

    ctx_labels = length(scope.labels) > 1 ? scope.labels[2:end] : String[]
    if !isempty(ctx_labels)
        print(io, ",\"labels\":")
        _write_json(io, ctx_labels)
    end
    if !isempty(ctx.data)
        print(io, ",\"data\":")
        _write_json(io, ctx.data)
    end
    print(io, "}")
end

function _write_commit_record(
    io::IO,
    session_label::String,
    commit_label::String,
    stage::Stage,
    meta::Dict,
    root_dir::String
)
    capture_blob_refs = Dict{Symbol, String}[]
    all_blob_refs = Set{String}()
    for ctx in stage.captures
        refs = _compute_blob_refs(ctx, root_dir)
        push!(capture_blob_refs, refs)
        union!(all_blob_refs, values(refs))
    end

    print(io, "{\"type\":\"commit\",\"session_label\":")
    _write_json(io, session_label)
    print(io, ",\"metadata\":")
    _write_json(io, meta)
    print(io, ",\"scopes\":[")
    for (i, ctx) in enumerate(stage.captures)
        i > 1 && print(io, ",")
        _write_capture_json(io, ctx, capture_blob_refs[i])
    end
    print(io, "],\"blob_refs\":")
    _write_json(io, collect(all_blob_refs))
    if !isempty(commit_label)
        print(io, ",\"commit_label\":")
        _write_json(io, commit_label)
    end
    print(io, "}")
end
