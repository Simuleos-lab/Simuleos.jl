# Recorder pipeline primitives — object-level, no workflow globals
# These functions work on Stage/CaptureContext objects with SimOs for Core-level resolution.
# The macro/global API layer (macros-I3x.jl, session-I3x.jl) resolves workflow globals
# and delegates here.
#
# Blob/lite classification is deferred to serialization time (here), not capture time.

# ==================================
# Constants
# ==================================

const MAX_TAPE_SIZE_BYTES = 200_000_000  # 200 MB threshold for tape file warnings

# ==================================
# _should_ignore_var — Pure function for variable filtering
# ==================================

"""
    _should_ignore_var(name, val, scope_label, simignore_rules) -> Bool

I0x — pure filtering logic (no SimOs integration)

Check if a variable should be ignored. Pure function (no recorder dependency).
"""
function _should_ignore_var(
        name::Symbol, val::Any,
        scope_label::String, simignore_rules::Vector
    )::Bool
    # Type-based filtering (always applied)
    val isa Module && return true
    val isa Function && return true

    # Rule-based filtering
    name_str = string(name)
    last_rule = nothing
    for rule in simignore_rules
        regex_matches = occursin(rule[:regex], name_str)
        regex_matches || continue
        rule_scope = get(rule, :scope, nothing)
        isnothing(rule_scope) || rule_scope == scope_label || continue
        last_rule = rule
    end

    isnothing(last_rule) && return false
    last_action = get(last_rule, :action, nothing)
    return last_action == :exclude
end

# ==================================
# Type string helper
# ==================================

function _get_type_string(val)::String
    return first(string(typeof(val)), 25)  # truncate to 25 chars
end

# ==================================
# Blob ref pre-computation (writes blobs, returns name→hash map)
# ==================================

function _compute_blob_refs(ctx::Kernel.CaptureContext, root_dir::String)::Dict{Symbol, String}
    refs = Dict{Symbol, String}()
    for (name, sv) in ctx.scope.variables
        if name in ctx.blob_set
            hash = Kernel._write_blob(root_dir, sv.val)
            refs[name] = hash
        end
    end
    return refs
end

# ==================================
# Variable JSON serialization (blob/lite classification at write time)
# ==================================

function _write_variable_json(io::IO, name::Symbol, sv::Kernel.ScopeVariable, blob_refs::Dict{Symbol, String})
    src_type = _get_type_string(sv.val)

    print(io, "{\"src_type\":")
    Kernel._write_json(io, src_type)
    print(io, ",\"src\":")
    Kernel._write_json(io, sv.src)

    if haskey(blob_refs, name)
        print(io, ",\"blob_ref\":")
        Kernel._write_json(io, blob_refs[name])
    elseif Kernel._is_lite(sv.val)
        print(io, ",\"value\":")
        Kernel._write_json(io, Kernel._liteify(sv.val))
    end
    # else: type-only — no value or blob_ref

    print(io, "}")
end

# ==================================
# CaptureContext JSON serialization
# ==================================

function _write_capture_json(io::IO, ctx::Kernel.CaptureContext, blob_refs::Dict{Symbol, String})
    scope = ctx.scope

    # First label is the primary "label" field (from @session_capture)
    print(io, "{\"label\":")
    Kernel._write_json(io, isempty(scope.labels) ? "" : scope.labels[1])
    print(io, ",\"timestamp\":")
    Kernel._write_json(io, ctx.timestamp)
    print(io, ",\"variables\":{")
    first_var = true
    for (name, sv) in scope.variables
        first_var || print(io, ",")
        first_var = false
        Kernel._write_json(io, string(name))
        print(io, ":")
        _write_variable_json(io, name, sv, blob_refs)
    end
    print(io, "}")

    # Additional labels (from @session_context) — skip first which is primary
    ctx_labels = length(scope.labels) > 1 ? scope.labels[2:end] : String[]
    if !isempty(ctx_labels)
        print(io, ",\"labels\":")
        Kernel._write_json(io, ctx_labels)
    end
    if !isempty(ctx.data)
        print(io, ",\"data\":")
        Kernel._write_json(io, ctx.data)
    end
    print(io, "}")
end

# ==================================
# Commit record serialization
# ==================================

# I0x — pure I/O serialization
function _write_commit_record(
    io::IO,
    session_label::String,
    commit_label::String,
    stage::Kernel.Stage,
    meta::Dict,
    root_dir::String
)
    # Pre-compute blob refs (writes blobs to disk)
    capture_blob_refs = Dict{Symbol, String}[]
    all_blob_refs = Set{String}()
    for ctx in stage.captures
        refs = _compute_blob_refs(ctx, root_dir)
        push!(capture_blob_refs, refs)
        union!(all_blob_refs, values(refs))
    end

    print(io, "{\"type\":\"commit\",\"session_label\":")
    Kernel._write_json(io, session_label)
    print(io, ",\"metadata\":")
    Kernel._write_json(io, meta)
    print(io, ",\"scopes\":[")
    for (i, ctx) in enumerate(stage.captures)
        i > 1 && print(io, ",")
        _write_capture_json(io, ctx, capture_blob_refs[i])
    end
    print(io, "],\"blob_refs\":")
    Kernel._write_json(io, collect(all_blob_refs))
    if !isempty(commit_label)
        print(io, ",\"commit_label\":")
        Kernel._write_json(io, commit_label)
    end
    print(io, "}")
end
