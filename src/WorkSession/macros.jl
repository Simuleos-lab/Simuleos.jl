# ============================================================
# WorkSession/macros.jl — Macro helpers and runtime functions
# ============================================================

function _remember_target_vars(target)
    if target isa Symbol
        return Symbol[target]
    end
    if target isa Expr && target.head == :tuple
        vars = Symbol[]
        for a in target.args
            a isa Symbol || error("@simos remember tuple target expects variable names, got: $a")
            push!(vars, a)
        end
        isempty(vars) && error("@simos remember tuple target cannot be empty.")
        return vars
    end
    error("@simos remember expects a variable name or tuple of variable names as target, got: $target")
end

function _remember_assign_expr(var::Symbol, value_expr)
    return :($(var) = $(value_expr))
end

function _remember_assign_expr(vars::Vector{Symbol}, value_expr)
    lhs = Expr(:tuple, vars...)
    return :($lhs = $(value_expr))
end

function _remember_value_expr(var::Symbol)
    return :($var)
end

function _remember_value_expr(vars::Vector{Symbol})
    return Expr(:tuple, vars...)
end

# NOTE: @isdefined is a best-effort guard — it catches unassigned targets but
# cannot distinguish a fresh assignment from a pre-existing binding.  This is a
# known limitation; the assign form (`@simos remember h x = expr`) is the reliable
# alternative when the target may already be in scope.
function _remember_defined_checks(vars::Vector{Symbol})
    checks = Expr[]
    for v in vars
        msg = "@simos remember miss branch did not leave `" * String(v) * "` defined."
        push!(checks, :((@isdefined $v) || error($msg)))
    end
    return checks
end

function _remember_is_extra_spec(expr)::Bool
    if !(expr isa Expr && expr.head == :tuple)
        return false
    end
    isempty(expr.args) && error("@simos remember extra key tuple cannot be empty.")

    is_pair(a) = a isa Expr && a.head == :(=) && length(a.args) == 2 && a.args[1] isa Symbol
    any_pairs = any(is_pair, expr.args)
    all_pairs = all(is_pair, expr.args)

    if all_pairs
        return true
    end
    if any_pairs
        error("@simos remember extra key tuple accepts only key=value pairs.")
    end
    return false
end

function _remember_extra_parts_expr(spec::Expr)
    spec.head == :tuple || error("@simos remember internal error: expected tuple extra key spec.")

    parts = Expr[]
    for item in spec.args
        if !(item isa Expr && item.head == :(=) && length(item.args) == 2 && item.args[1] isa Symbol)
            error("@simos remember extra key tuple accepts only key=value pairs, got: $item")
        end
        push!(parts, :(($(string(item.args[1])), $(item.args[2]))))
    end
    return :(Any[$(parts...)])
end

function _require_active_worksession_and_project()
    sim = _Krn._get_simos()
    ws = sim.worksession
    isnothing(ws) && error("No active session. Call `@simos session.init(...)` first.")
    proj = _Krn.sim_project(sim)
    return ws, proj
end

function _ctx_hash_record!(label::AbstractString, entries::AbstractVector{<:Tuple})::String
    sim = _Krn._get_simos()
    ws = sim.worksession
    isnothing(ws) && error("No active session. Call `@simos session.init(...)` first.")
    key_label = strip(String(label))
    isempty(key_label) && error("@simos ctx_hash label must be a non-empty string.")
    hash = _ctx_hash_from_named_entries(label, entries)
    ws.context_hash_reg[key_label] = hash
    return hash
end

function _normalize_batch_commit_limit(value)::Int
    value isa Integer || error("Batch commit threshold must be an integer, got: $(typeof(value))")
    n = Int(value)
    n >= 1 || error("Batch commit threshold must be >= 1, got: $(n)")
    return n
end

function _batch_commit_limit(ws::_Krn.WorkSession, max_pending_commits)::Int
    raw = isnothing(max_pending_commits) ?
        session_setting(ws, _Krn.SETTING_KEY_BATCH_COMMIT_MAX_PENDING) :
        max_pending_commits
    return _normalize_batch_commit_limit(raw)
end

function _normalize_commit_every(value)::Int
    value isa Integer || error("`cmt_every` must be an integer, got: $(typeof(value))")
    n = Int(value)
    n >= 1 || error("`cmt_every` must be >= 1, got: $(n)")
    return n
end

function _batch_commit_gate_allows_queue!(ws::_Krn.WorkSession, label::String, cmt_every)::Bool
    isnothing(cmt_every) && return true

    every = _normalize_commit_every(cmt_every)
    next_count = get(ws.queue_counters, label, 0) + 1
    if next_count >= every
        ws.queue_counters[label] = 0
        return true
    end

    ws.queue_counters[label] = next_count
    return false
end

function _apply_commit_capture_filters!(ws::_Krn.WorkSession, commit::_Krn.RecCaptureCommitV1)::_Krn.RecCaptureCommitV1
    tree = commit.capture
    for i in eachindex(tree.snapshots)
        s = tree.snapshots[i]
        if s isa _Krn.SnapScopeV1
            tree.snapshots[i] = _WS.apply_capture_filters(s, ws)
        end
    end
    return commit
end

function _take_stage_commit_filtered!(ws::_Krn.WorkSession, gh; label::String = "")::_Krn.RecCaptureCommitV1
    meta = _session_commit_metadata(gh)
    commit = _Krn.take_stage_commit!(ws.stage, ws.capture_policy; label=label, metadata=meta)
    return _apply_commit_capture_filters!(ws, commit)
end

function _queue_stage_commit!(ws::_Krn.WorkSession, gh; label::String = "")::_Krn.RecCaptureCommitV1
    commit = _take_stage_commit_filtered!(ws, gh; label=label)
    push!(ws.pending_commits, commit)
    ws.is_finalized = false
    return commit
end

function _flush_pending_commits!(proj::_Krn.SimuleosProject, ws::_Krn.WorkSession;
        commit_writer = _Krn.commit_to_tape!
    )::Int
    n = length(ws.pending_commits)
    n == 0 && return 0

    tape = _Krn.session_tape(proj, ws.session_id)
    flushed = 0
    try
        for i in 1:n
            commit_writer(tape, ws.pending_commits[i])
            flushed = i
        end
    catch
        # Preserve only the unflushed suffix so retries do not duplicate writes.
        flushed > 0 && deleteat!(ws.pending_commits, 1:flushed)
        rethrow()
    end
    empty!(ws.pending_commits)
    return n
end

function scope_capture(
        label::String,
        locals::AbstractDict{Symbol, Any},
        globals::AbstractDict{Symbol, Any},
        src_file::String,
        src_line::Int
    )
    # Hot path: this runs on every capture call; allocation/perf optimizations are always welcome.
    sim = _Krn._get_simos()
    ws = sim.worksession
    isnothing(ws) && error("No active session. Call `@simos session.init(...)` first.")
    proj = _Krn.sim_project(sim)

    scope = _Krn.SnapScopeV1()
    policy = ws.capture_policy
    for (name, val) in locals
        _Krn.is_capture_excluded(val) && continue
        scope.variables[name] = _Krn._make_scope_variable(
            :local, val, policy.inline_vars, policy.blob_vars, policy.hash_vars, name, proj.blobstorage
        )
    end
    for (name, val) in globals
        _Krn.is_capture_excluded(val) && continue
        haskey(scope.variables, name) && continue
        scope.variables[name] = _Krn._make_scope_variable(
            :global, val, policy.inline_vars, policy.blob_vars, policy.hash_vars, name, proj.blobstorage
        )
    end

    !isempty(label) && pushfirst!(scope.labels, label)
    exec = _Krn.capture_execution(src_file, src_line)
    scope.metadata[:src_file] = exec.src_file
    scope.metadata[:src_line] = exec.src_line
    scope.metadata[:threadid] = exec.threadid
    scope.metadata[:timestamp] = exec.timestamp

    if !isempty(policy.meta_buffer)
        merge!(scope.metadata, policy.meta_buffer)
        empty!(policy.meta_buffer)
    end

    push!(ws.stage.snapshots, scope)
    ws.is_finalized = false
    return scope
end

function session_commit(label::String="")
    ws, proj = _require_active_worksession_and_project()

    # Preserve logical commit order when mixing queued and immediate commit paths.
    _flush_pending_commits!(proj, ws)
    tape = _Krn.session_tape(proj, ws.session_id)
    commit = _take_stage_commit_filtered!(ws, proj.git_handler; label=label)
    _Krn.commit_to_tape!(tape, commit)
    ws.is_finalized = false
    return commit
end

function session_batch_commit(label::String=""; max_pending_commits = nothing, cmt_every = nothing)
    ws, proj = _require_active_worksession_and_project()
    _batch_commit_gate_allows_queue!(ws, label, cmt_every) || return nothing
    limit = _batch_commit_limit(ws, max_pending_commits)

    commit = _queue_stage_commit!(ws, proj.git_handler; label=label)
    if length(ws.pending_commits) >= limit
        _flush_pending_commits!(proj, ws)
    end
    return commit
end

function session_finalize(label::String="")
    ws, proj = _require_active_worksession_and_project()

    queued_tail_commit = false
    if !isempty(ws.stage.snapshots)
        _queue_stage_commit!(ws, proj.git_handler; label=label)
        queued_tail_commit = true
    end

    flushed_commits = _flush_pending_commits!(proj, ws)
    empty!(ws.queue_counters)
    ws.is_finalized = true
    return (
        queued_tail_commit = queued_tail_commit,
        flushed_commits = flushed_commits,
    )
end
