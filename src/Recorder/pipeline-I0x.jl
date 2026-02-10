# Recorder pipeline primitives — object-level, no workflow globals
# These functions work on Stage/Scope objects with SimOs for Core-level resolution.
# The macro/global API layer (macros-I3x.jl, session-I3x.jl) resolves workflow globals
# and delegates here.

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
# I/O Helpers (internal)
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
    print(io, "{\"type\":\"commit\",\"session_label\":")
    Kernel._write_json(io, session_label)
    print(io, ",\"metadata\":")
    Kernel._write_json(io, meta)
    print(io, ",\"scopes\":[")
    for (i, scope) in enumerate(stage.scopes)
        i > 1 && print(io, ",")
        Kernel._write_json(io, scope)
    end
    print(io, "],\"blob_refs\":")
    Kernel._write_json(io, _collect_blob_refs(stage.scopes))
    if !isempty(commit_label)
        print(io, ",\"commit_label\":")
        Kernel._write_json(io, commit_label)
    end
    print(io, "}")
end

# I0x — pure data extraction
function _collect_blob_refs(scopes::Vector{Kernel.Scope})::Vector{String}
    refs = Set{String}()
    for scope in scopes
        for (_, sv) in scope.variables
            if !isnothing(sv.blob_ref)
                push!(refs, sv.blob_ref)
            end
        end
    end
    return collect(refs)
end

function _get_type_string(val)::String
    return first(string(typeof(val)), 25)  # truncate to 25 chars
end