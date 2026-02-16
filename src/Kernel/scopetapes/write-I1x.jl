# ScopeTapes write orchestration (all I1x)
# Explicit dependencies are passed as arguments.

"""
    _fill_scope!(stage, locals, globals, src_file, src_line, label; simignore_rules)

Finalize one scope capture from locals/globals and append to `stage.captures`.
Uses `stage.current_scope` for pending labels/context and `stage.blob_refs` for
blob-backed variables. Resets current scope and blob refs after capture.
"""
function _fill_scope!(
    stage::ScopeStage,
    locals::Dict{Symbol, Any},
    globals::Dict{Symbol, Any},
    src_file::String,
    src_line::Int,
    label::String;
    simignore_rules::Vector
)
    labels = vcat([label], stage.current_scope.labels)
    scope = SimuleosScope(labels, locals, globals)
    scope.data = copy(stage.current_scope.data)
    scope.data[:src_file] = src_file
    scope.data[:src_line] = src_line
    scope.data[:threadid] = Threads.threadid()

    scope = filter_rules(scope, simignore_rules)
    scope = _materialize_scope_variables!(scope, stage.blob_refs)

    push!(stage.captures, scope)
    stage.current_scope = SimuleosScope()
    empty!(stage.blob_refs)
    return stage.captures[end]
end

"""
    commit_stage!(tape::TapeIO, stage::ScopeStage, meta::Dict{String, Any}; commit_label="")

Build a commit payload from the stage and append it to tape.
"""
function commit_stage!(
    tape::TapeIO,
    stage::ScopeStage,
    meta::Dict{String, Any};
    commit_label::String = ""
)
    commit = _stage_to_scope_commit(commit_label, stage, meta)
    record = _scope_commit_to_dict(commit)
    append!(tape, record)

    tape_size = filesize(tape.path)
    if tape_size > MAX_TAPE_SIZE_BYTES
        @warn "Tape file is large" path=tape.path size_mb=round(tape_size / 1_000_000; digits=1)
    end

    return nothing
end
