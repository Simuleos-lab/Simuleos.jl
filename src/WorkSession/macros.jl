# ============================================================
# WorkSession/macros.jl — User-facing macros
# ============================================================

function _extract_symbols(expr)
    if expr isa Symbol
        return Symbol[expr]
    elseif expr isa Expr
        out = Symbol[]
        for a in expr.args
            append!(out, _extract_symbols(a))
        end
        return out
    end
    return Symbol[]
end

function _remember_target_vars(target)
    if target isa Symbol
        return Symbol[target]
    end
    if target isa Expr && target.head == :tuple
        vars = Symbol[]
        for a in target.args
            a isa Symbol || error("@remember tuple target expects variable names, got: $a")
            push!(vars, a)
        end
        isempty(vars) && error("@remember tuple target cannot be empty.")
        return vars
    end
    error("@remember expects a variable name or tuple of variable names as target, got: $target")
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
# known limitation; the assign form (`@remember h x = expr`) is the reliable
# alternative when the target may already be in scope.
function _remember_defined_checks(vars::Vector{Symbol})
    checks = Expr[]
    for v in vars
        msg = "@remember miss branch did not assign `" * String(v) * "`."
        push!(checks, :((@isdefined $v) || error($msg)))
    end
    return checks
end

function _remember_is_extra_spec(expr)::Bool
    if !(expr isa Expr && expr.head == :tuple)
        return false
    end
    isempty(expr.args) && error("@remember extra key tuple cannot be empty.")
    return any(!(a isa Symbol) for a in expr.args)
end

function _remember_extra_parts_expr(spec::Expr)
    spec.head == :tuple || error("@remember internal error: expected tuple extra key spec.")

    parts = Expr[]
    for item in spec.args
        if item isa Expr && item.head == :(=) && length(item.args) == 2 && item.args[1] isa Symbol
            push!(parts, :(($(string(item.args[1])), $(item.args[2]))))
        else
            push!(parts, item)
        end
    end
    return :(Any[$(parts...)])
end

const _BATCH_COMMIT_MAX_PENDING_DEFAULT = 10
const _BATCH_COMMIT_MAX_PENDING_KEY = "worksession.batch_commit.max_pending_commits"

function _require_active_worksession_and_project()
    sim = _Kernel._get_sim()
    ws = sim.worksession
    isnothing(ws) && error("No active session. Call @session_init first.")
    proj = _Kernel.sim_project(sim)
    return ws, proj
end

function _ctx_hash_digest(parts...)::String
    return _Kernel.blob_ref(("ctx_hash_v1", parts...)).hash
end

function _ctx_hash_extra_parts(extra_parts)::Vector{Any}
    isnothing(extra_parts) && return Any[]

    if extra_parts isa NamedTuple
        parts = Any[]
        for (k, v) in pairs(extra_parts)
            push!(parts, (String(k), v))
        end
        return parts
    end

    if extra_parts isa Tuple || extra_parts isa AbstractVector
        return Any[extra_parts...]
    end

    return Any[extra_parts]
end

function _ctx_hash_compose(ctx_hash, extra_parts = nothing)::String
    h = strip(String(ctx_hash))
    isempty(h) && error("Context hash must be a non-empty string.")

    parts = _ctx_hash_extra_parts(extra_parts)
    isempty(parts) && return h
    return _ctx_hash_digest("ctx_hash_compose_v1", h, parts)
end

function _ctx_hash_from_named_entries(label::AbstractString, entries::AbstractVector{<:Tuple})::String
    key_label = strip(String(label))
    isempty(key_label) && error("@ctx_hash label must be a non-empty string.")

    normalized = Tuple{String, Any}[]
    for item in entries
        length(item) == 2 || error("@ctx_hash internal error: expected (name, value) entries.")
        name = strip(String(item[1]))
        isempty(name) && error("@ctx_hash variable labels must be non-empty.")
        push!(normalized, (name, item[2]))
    end

    # Keep the original @ctx_hash key layout to avoid unnecessary cache invalidation.
    return _ctx_hash_digest(key_label, normalized)
end

function _ctx_hash_record!(label::AbstractString, entries::AbstractVector{<:Tuple})::String
    sim = _Kernel._get_sim()
    ws = sim.worksession
    isnothing(ws) && error("No active session. Call @session_init first.")
    key_label = strip(String(label))
    isempty(key_label) && error("@ctx_hash label must be a non-empty string.")
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

function _batch_commit_limit(ws::_Kernel.WorkSession, max_pending_commits)::Int
    raw = isnothing(max_pending_commits) ?
        session_setting(ws, _BATCH_COMMIT_MAX_PENDING_KEY, _BATCH_COMMIT_MAX_PENDING_DEFAULT) :
        max_pending_commits
    return _normalize_batch_commit_limit(raw)
end

function _queue_stage_commit!(ws::_Kernel.WorkSession, gh; label::String = "")::_Kernel.ScopeCommit
    meta = _session_commit_metadata(gh)
    commit = _Kernel.take_stage_commit!(ws.stage; label=label, metadata=meta)
    push!(ws.pending_commits, commit)
    ws.is_finalized = false
    return commit
end

function _flush_pending_commits!(proj::_Kernel.SimuleosProject, ws::_Kernel.WorkSession)::Int
    n = length(ws.pending_commits)
    n == 0 && return 0

    tape = _Kernel.TapeIO(_Kernel.tape_path(proj, ws.session_id))
    for commit in ws.pending_commits
        _Kernel.commit_to_tape!(tape, commit)
    end
    empty!(ws.pending_commits)
    return n
end

"""
    @session_init(labels...)

Initialize a recording session with the given labels.
Must be called after `sim_init!()`.

# Example
```julia
sim_init!()
@session_init "experiment1" "run-alpha"
```
"""
macro session_init(labels...)
    src = string(__source__.file)
    src_line = __source__.line
    quote
        $(_WS).session_init_from_macro!(Any[$(labels...)], $src, $src_line)
    end |> esc
end

"""
    @session_store(vars...)

Mark variables for blob storage instead of inline JSON.
Use for large objects like arrays, DataFrames, etc.

# Example
```julia
@session_store big_matrix results_df
```
"""
macro session_store(vars...)
    stmts = Expr[]
    for v in vars
        v isa Symbol || error("@session_store expects variable names, got: $v")
        push!(stmts, quote
            let sim = $(_Kernel)._get_sim()
                isnothing(sim.worksession) && error("No active session. Call @session_init first.")
                push!(sim.worksession.stage.blob_vars, $(QuoteNode(v)))
            end
        end)
    end
    esc(Expr(:block, stmts...))
end

"""
    @scope_inline(vars...)

Mark variables for inline JSON storage (overrides the default Void behavior
for non-lite types). Use for values you want recorded in the tape JSON.

# Example
```julia
@scope_inline my_vector config_dict
```
"""
macro scope_inline(vars...)
    stmts = Expr[]
    for v in vars
        v isa Symbol || error("@scope_inline expects variable names, got: $v")
        push!(stmts, quote
            let sim = $(_Kernel)._get_sim()
                isnothing(sim.worksession) && error("No active session. Call @session_init first.")
                push!(sim.worksession.stage.inline_vars, $(QuoteNode(v)))
            end
        end)
    end
    esc(Expr(:block, stmts...))
end

"""
    @scope_meta(pairs...)

Add metadata key-value pairs to the next scope capture.

# Example
```julia
@scope_meta step=1 phase="training"
```
"""
macro scope_meta(pairs...)
    stmts = Expr[]
    for p in pairs
        if p isa Expr && p.head == :(=)
            k = QuoteNode(p.args[1])
            v = p.args[2]
            push!(stmts, quote
                let sim = $(_Kernel)._get_sim()
                    isnothing(sim.worksession) && error("No active session.")
                    sim.worksession.stage.meta_buffer[$k] = $v
                end
            end)
        else
            error("@scope_meta expects key=value pairs, got: $p")
        end
    end
    esc(Expr(:block, stmts...))
end

"""
    @ctx_hash(label, vars_or_pairs...)

Compute a deterministic context hash from a user label plus selected values from
the current scope, store it in the active session registry, and return the hash.

Accepted inputs after `label`:
- symbols (captured by current value): `x y`
- explicit pairs: `tol=1e-6 method="fast"`

# Example
```julia
h = @ctx_hash "solver-input" model eps tol=1e-6
```
"""
macro ctx_hash(label, vars_or_pairs...)
    entries = Expr[]
    for item in vars_or_pairs
        if item isa Symbol
            push!(entries, :(($(string(item)), $item)))
        elseif item isa Expr && item.head == :(=) && length(item.args) == 2 && item.args[1] isa Symbol
            push!(entries, :(($(string(item.args[1])), $(item.args[2]))))
        else
            error("@ctx_hash expects variable names and/or key=value pairs, got: $item")
        end
    end

    quote
        $(_WS)._ctx_hash_record!(
            string($label),
            Tuple{String, Any}[$(entries...)]
        )
    end |> esc
end

"""
    @remember(ctx_hash, target, body)
    @remember(ctx_hash, target = expr)
    @remember(ctx_hash, (extra_key_parts...), target, body)
    @remember(ctx_hash, (extra_key_parts...), target = expr)

Scope-oriented keyed cache macro.
- `target` can be a variable (`x`) or tuple (`(a, b)`).
- Optional `extra_key_parts` are composed into the context hash before lookup/store.
  Use this to partition cache entries under the same base `ctx_hash` without
  changing the original `@ctx_hash` registry entry.
- On cache hit, assigns cached value(s) into caller scope and skips recomputation.
- On cache miss, runs the miss branch, checks target assignment (block form),
  stores the resulting value(s), and returns `:miss`.

Returns `:hit` or `:miss`.
"""
macro remember(ctx_hash_expr, rest...)
    isempty(rest) && error("@remember expects a target and payload.")

    args = Any[rest...]
    extra_parts_expr = nothing
    if _remember_is_extra_spec(args[1])
        extra_parts_expr = _remember_extra_parts_expr(args[1])
        args = args[2:end]
        isempty(args) && error("@remember extra key tuple must be followed by a target.")
    end
    length(args) in (1, 2) || error("@remember expects `@remember h target begin ... end`, `@remember h target = expr`, or the same with an extra key tuple before `target`.")

    local target_expr
    local payload_expr
    local mode

    if length(args) == 1
        arg = args[1]
        if !(arg isa Expr && arg.head == :(=) && length(arg.args) == 2)
            error("@remember single-tail form expects assignment: `@remember h target = expr`.")
        end
        target_expr = arg.args[1]
        payload_expr = arg.args[2]
        mode = :assign
    else
        target_expr = args[1]
        payload_expr = args[2]
        mode = :block
    end

    vars = _remember_target_vars(target_expr)
    ns_expr = length(vars) == 1 ?
        :($(_WS)._remember_namespace($(QuoteNode(vars[1])))) :
        :($(_WS)._remember_namespace(Symbol[$([QuoteNode(v) for v in vars]...)]))

    hit_assign_expr = length(vars) == 1 ?
        _remember_assign_expr(vars[1], :_remember_cached_value) :
        _remember_assign_expr(vars, :_remember_cached_value)
    miss_value_expr = length(vars) == 1 ? _remember_value_expr(vars[1]) : _remember_value_expr(vars)
    defined_checks = _remember_defined_checks(vars)
    composed_ctx_expr = isnothing(extra_parts_expr) ?
        :(string($ctx_hash_expr)) :
        :($(_WS)._ctx_hash_compose(string($ctx_hash_expr), $extra_parts_expr))

    miss_branch_expr = if mode == :assign
        Expr(:block,
            _remember_assign_expr(length(vars) == 1 ? vars[1] : vars, :_remember_miss_value),
            :($(_WS)._remember_store!(_remember_ns, _remember_ctx_hash, $miss_value_expr)),
            QuoteNode(:miss),
        )
    else
        Expr(:block,
            payload_expr,
            defined_checks...,
            :($(_WS)._remember_store!(_remember_ns, _remember_ctx_hash, $miss_value_expr)),
            QuoteNode(:miss),
        )
    end

    quote
        local _remember_ctx_hash = $composed_ctx_expr
        local _remember_ns = $ns_expr
        local _remember_hit, _remember_cached_value = $(_WS)._remember_tryload(_remember_ns, _remember_ctx_hash)
        if _remember_hit
            $hit_assign_expr
            $(QuoteNode(:hit))
        else
            $(mode == :assign ? :(local _remember_miss_value = $payload_expr) : nothing)
            $miss_branch_expr
        end
    end |> esc
end

"""
    @scope_capture(label="")

Capture the current scope (local + global variables) and add it to
the session's staging area.

Variables are filtered by simignore rules.
Variables marked with @session_store are saved as blobs.

# Example
```julia
for i in 1:10
    x = compute(i)
    @scope_capture "iteration"
end
@session_commit "training_loop"
```
"""
macro scope_capture(label="")
    mod = __module__
    src_file = string(__source__.file)
    src_line = __source__.line
    quote
        let
            _locals = Base.@locals
            _globals = Dict{Symbol, Any}()
            for name in names($mod; all=false)
                haskey(_locals, name) && continue
                isdefined($mod, name) || continue
                _globals[name] = getfield($mod, name)
            end

            $(_WS).scope_capture(
                string($label),
                _locals,
                _globals,
                $src_file,
                $src_line,
            )
        end
    end |> esc
end

"""
    @session_commit(label="")

Commit all staged scopes to the tape file and clear the stage.

# Example
```julia
@session_commit "epoch_1"
```
"""
macro session_commit(label="")
    quote
        $(_WS).session_commit(string($label))
    end |> esc
end

"""
    @session_batch_commit(label="")

Convert staged scopes into a `ScopeCommit`, queue it in memory, and flush the
queued commits to tape when the pending-commit threshold is reached.
"""
macro session_batch_commit(label="")
    quote
        $(_WS).session_batch_commit(string($label))
    end |> esc
end

"""
    @session_finalize(label="")

Flush session recording buffers:
1. If staged scopes remain, convert them into one final queued commit.
2. Flush all queued commits to tape.

Does not end the active work session.
"""
macro session_finalize(label="")
    quote
        $(_WS).session_finalize(string($label))
    end |> esc
end

function scope_capture(
        label::String,
        locals::AbstractDict{Symbol, Any},
        globals::AbstractDict{Symbol, Any},
        src_file::String,
        src_line::Int
    )
    # Hot path: this runs on every capture call; allocation/perf optimizations are always welcome.
    sim = _Kernel._get_sim()
    ws = sim.worksession
    isnothing(ws) && error("No active session. Call @session_init first.")
    proj = _Kernel.sim_project(sim)

    scope = _Kernel.SimuleosScope()
    for (name, val) in locals
        _Kernel.is_capture_excluded(val) && continue
        scope.variables[name] = _Kernel._make_scope_variable(
            :local, val, ws.stage.inline_vars, ws.stage.blob_vars, name, proj.blobstorage
        )
    end
    for (name, val) in globals
        _Kernel.is_capture_excluded(val) && continue
        haskey(scope.variables, name) && continue
        scope.variables[name] = _Kernel._make_scope_variable(
            :global, val, ws.stage.inline_vars, ws.stage.blob_vars, name, proj.blobstorage
        )
    end

    scope = _Kernel.filter_rules(scope, ws.simignore_rules)
    !isempty(label) && pushfirst!(scope.labels, label)
    scope.metadata[:src_file] = src_file
    scope.metadata[:src_line] = src_line
    scope.metadata[:threadid] = Threads.threadid()

    if !isempty(ws.stage.meta_buffer)
        merge!(scope.metadata, ws.stage.meta_buffer)
        empty!(ws.stage.meta_buffer)
    end

    push!(ws.stage.captures, scope)
    ws.is_finalized = false
    return scope
end

function session_commit(label::String="")
    ws, proj = _require_active_worksession_and_project()

    # Preserve logical commit order when mixing queued and immediate commit paths.
    _flush_pending_commits!(proj, ws)
    tape = _Kernel.TapeIO(_Kernel.tape_path(proj, ws.session_id))
    meta = _session_commit_metadata(proj.git_handler)
    commit = _Kernel.commit_stage!(tape, ws.stage; label=label, metadata=meta)
    ws.is_finalized = false
    return commit
end

function session_batch_commit(label::String=""; max_pending_commits = nothing)
    ws, proj = _require_active_worksession_and_project()
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
    if !isempty(ws.stage.captures)
        _queue_stage_commit!(ws, proj.git_handler; label=label)
        queued_tail_commit = true
    end

    flushed_commits = _flush_pending_commits!(proj, ws)
    ws.is_finalized = true
    return (
        queued_tail_commit = queued_tail_commit,
        flushed_commits = flushed_commits,
    )
end
