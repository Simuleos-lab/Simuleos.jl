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
    quote
        $(_WS).session_init_from_macro!(Any[$(labels...)], $src)
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
    return scope
end

function session_commit(label::String="")
    sim = _Kernel._get_sim()
    ws = sim.worksession
    isnothing(ws) && error("No active session. Call @session_init first.")
    proj = _Kernel.sim_project(sim)

    tape = _Kernel.TapeIO(_Kernel.tape_path(proj, ws.session_id))
    meta = _session_commit_metadata(proj.git_handler)

    return _Kernel.commit_stage!(tape, ws.stage; label=label, metadata=meta)
end
