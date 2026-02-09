# Recorder pipeline primitives — object-level, no workflow globals
# These functions work on Stage/Scope objects with SimOs for Core-level resolution.
# The macro/global API layer (macros.jl, session.jl) resolves workflow globals
# and delegates here.

# ==================================
# Variable Processing (helper)
# ==================================

function _process_var!(
        scope::Core.Scope,
        sym::Symbol, val::Any, src::Symbol,
        root_dir::String
    )
    name = string(sym)
    src_type = first(string(typeof(val)), 25)  # truncate to 25 chars

    if sym in scope.blob_set
        hash = Core._write_blob(root_dir, val)
        scope.variables[name] = Core.ScopeVariable(
            name=name, src_type=src_type,
            value=nothing, blob_ref=hash, src=src
        )
    elseif Core._is_lite(val)
        scope.variables[name] = Core.ScopeVariable(
            name=name, src_type=src_type,
            value=Core._liteify(val), blob_ref=nothing, src=src
        )
    else
        scope.variables[name] = Core.ScopeVariable(
            name=name, src_type=src_type,
            value=nothing, blob_ref=nothing, src=src
        )
    end
end

# ==================================
# _fill_scope! — Populate scope from raw variables
# ==================================

"""
    _fill_scope!(scope, stage, locals, globals, src_file, src_line, label; simignore_rules, simos)

Fill a Scope object from raw locals/globals dictionaries.
Applies simignore filtering, writes blobs, liteifies values.

# Arguments
- `scope::Scope`: The scope object to fill
- `stage::Stage`: The current stage (for blob_set tracking)
- `locals::Dict{Symbol,Any}`: Local variables captured from caller
- `globals::Dict{Symbol,Any}`: Global variables captured from Main
- `src_file::String`: Source file path
- `src_line::Int`: Source line number
- `label::String`: Scope label
- `simignore_rules::Vector`: Simignore rules (from SessionRecorder)
- `simos::SimOs`: Core system state (for project root, settings)
"""
function _fill_scope!(
    scope::Core.Scope,
    stage::Core.Stage,
    locals::Dict{Symbol,Any},
    globals::Dict{Symbol,Any},
    src_file::String,
    src_line::Int,
    label::String;
    simignore_rules::Vector,
    simos::Core.SimOs
)
    root_dir = Core.project(simos).simuleos_dir

    # Process globals first (can be overridden by locals)
    for (sym, val) in globals
        _should_ignore_var(sym, val, label, simignore_rules) && continue
        _process_var!(scope, sym, val, :global, root_dir)
    end

    # Process locals (override globals if same name)
    for (sym, val) in locals
        _should_ignore_var(sym, val, label, simignore_rules) && continue
        _process_var!(scope, sym, val, :local, root_dir)
    end

    # Set scope metadata
    scope.label = label
    scope.timestamp = Dates.now()
    scope.isopen = false
    scope.data[:src_file] = src_file
    scope.data[:src_line] = src_line
    scope.data[:threadid] = Threads.threadid()

    return scope
end

# ==================================
# _should_ignore_var — Pure function for variable filtering
# ==================================

"""
    _should_ignore_var(name, val, scope_label, simignore_rules) -> Bool

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
# write_commit_to_tape — Persist stage to tape
# ==================================

"""
    write_commit_to_tape(session_label, commit_label, stage, meta; simos)

Write a commit record from the stage to the session's tape file.

# Arguments
- `session_label::String`: Session identifier
- `commit_label::String`: Commit label (can be empty)
- `stage::Stage`: The stage containing scopes to commit
- `meta::Dict`: Session metadata
- `simos::SimOs`: Core system state (for project root)
"""
function write_commit_to_tape(
    session_label::String,
    commit_label::String,
    stage::Core.Stage,
    meta::Dict;
    simos::Core.SimOs
)
    root_dir = Core.project(simos).simuleos_dir

    # Build session directory and tape path
    safe_label = replace(session_label, r"[^\w\-]" => "_")
    session_dir = joinpath(root_dir, "sessions", safe_label)
    tapes_dir = joinpath(session_dir, "tapes")
    mkpath(tapes_dir)

    tape_path = joinpath(tapes_dir, "context.tape.jsonl")

    open(tape_path, "a") do io
        _write_commit_record(io, session_label, commit_label, stage, meta, root_dir)
        println(io)
    end
end

# ==================================
# I/O Helpers (internal)
# ==================================

function _write_commit_record(
    io::IO,
    session_label::String,
    commit_label::String,
    stage::Core.Stage,
    meta::Dict,
    root_dir::String
)
    print(io, "{\"type\":\"commit\",\"session_label\":")
    Core._write_json(io, session_label)
    print(io, ",\"metadata\":")
    Core._write_json(io, meta)
    print(io, ",\"scopes\":[")
    for (i, scope) in enumerate(stage.scopes)
        i > 1 && print(io, ",")
        Core._write_json(io, scope)
    end
    print(io, "],\"blob_refs\":")
    Core._write_json(io, _collect_blob_refs(stage.scopes))
    if !isempty(commit_label)
        print(io, ",\"commit_label\":")
        Core._write_json(io, commit_label)
    end
    print(io, "}")
end

function _collect_blob_refs(scopes::Vector{Core.Scope})::Vector{String}
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
