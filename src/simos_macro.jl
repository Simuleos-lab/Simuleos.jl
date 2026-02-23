# ============================================================
# simos_macro.jl — Unified @simos dispatch macro
# ============================================================

const _SimWS = WorkSession
const _SimSR = ScopeReader
const _SimKrn = Kernel

const _SIMOS_VERBS = (:init, :store, :hash, :inline, :meta, :capture,
    :commit, :batch_commit, :finalize, :ctx_hash, :remember, :expand)

function _simos_verb_list_str()
    return join(string.(_SIMOS_VERBS), ", ")
end

# ------------------------------------------------------------------
# Handlers — each returns an Expr (already esc'd by dispatcher)
# ------------------------------------------------------------------

function _simos_init(mod, src, args)
    src_file = string(src.file)
    src_line = src.line
    return quote
        $(_SimWS).session_init_from_macro!(Any[$(args...)], $src_file, $src_line)
    end
end

function _simos_store(mod, src, args)
    stmts = Expr[]
    for v in args
        v isa Symbol || error("@simos store expects variable names, got: $v")
        push!(stmts, quote
            let sim = $(_SimKrn)._get_sim()
                isnothing(sim.worksession) && error("No active session. Call @simos init first.")
                push!(sim.worksession.stage.blob_vars, $(QuoteNode(v)))
            end
        end)
    end
    return Expr(:block, stmts...)
end

function _simos_hash(mod, src, args)
    stmts = Expr[]
    for v in args
        v isa Symbol || error("@simos hash expects variable names, got: $v")
        push!(stmts, quote
            let sim = $(_SimKrn)._get_sim()
                isnothing(sim.worksession) && error("No active session. Call @simos init first.")
                push!(sim.worksession.stage.hash_vars, $(QuoteNode(v)))
            end
        end)
    end
    return Expr(:block, stmts...)
end

function _simos_inline(mod, src, args)
    stmts = Expr[]
    for v in args
        v isa Symbol || error("@simos inline expects variable names, got: $v")
        push!(stmts, quote
            let sim = $(_SimKrn)._get_sim()
                isnothing(sim.worksession) && error("No active session. Call @simos init first.")
                push!(sim.worksession.stage.inline_vars, $(QuoteNode(v)))
            end
        end)
    end
    return Expr(:block, stmts...)
end

function _simos_meta(mod, src, args)
    stmts = Expr[]
    for p in args
        if p isa Expr && p.head == :(=)
            k = QuoteNode(p.args[1])
            v = p.args[2]
            push!(stmts, quote
                let sim = $(_SimKrn)._get_sim()
                    isnothing(sim.worksession) && error("No active session.")
                    sim.worksession.stage.meta_buffer[$k] = $v
                end
            end)
        else
            error("@simos meta expects key=value pairs, got: $p")
        end
    end
    return Expr(:block, stmts...)
end

function _simos_capture(mod, src, args)
    label_expr = isempty(args) ? "" : args[1]
    src_file = string(src.file)
    src_line = src.line
    return quote
        let
            _locals = Base.@locals
            _globals = Dict{Symbol, Any}()
            for name in names($mod; all=false)
                haskey(_locals, name) && continue
                isdefined($mod, name) || continue
                _globals[name] = getfield($mod, name)
            end

            $(_SimWS).scope_capture(
                string($label_expr),
                _locals,
                _globals,
                $src_file,
                $src_line,
            )
        end
    end
end

function _simos_commit(mod, src, args)
    label_expr = isempty(args) ? "" : args[1]
    return quote
        $(_SimWS).session_commit(string($label_expr))
    end
end

function _simos_batch_commit(mod, src, args)
    label_expr = isempty(args) ? "" : args[1]
    return quote
        $(_SimWS).session_batch_commit(string($label_expr))
    end
end

function _simos_finalize(mod, src, args)
    label_expr = isempty(args) ? "" : args[1]
    return quote
        $(_SimWS).session_finalize(string($label_expr))
    end
end

function _simos_ctx_hash(mod, src, args)
    isempty(args) && error("@simos ctx_hash requires a label and optional vars/pairs.")
    label = args[1]
    vars_or_pairs = args[2:end]

    entries = Expr[]
    for item in vars_or_pairs
        if item isa Symbol
            push!(entries, :(($(string(item)), $item)))
        elseif item isa Expr && item.head == :(=) && length(item.args) == 2 && item.args[1] isa Symbol
            push!(entries, :(($(string(item.args[1])), $(item.args[2]))))
        else
            error("@simos ctx_hash expects variable names and/or key=value pairs, got: $item")
        end
    end

    return quote
        $(_SimWS)._ctx_hash_record!(
            string($label),
            Tuple{String, Any}[$(entries...)]
        )
    end
end

function _simos_remember(mod, src, args)
    isempty(args) && error("@simos remember expects a ctx_hash, target, and payload.")

    ctx_hash_expr = args[1]
    rest = args[2:end]
    isempty(rest) && error("@simos remember expects a target and payload.")

    parsed_args = Any[rest...]
    extra_parts_expr = nothing
    if _SimWS._remember_is_extra_spec(parsed_args[1])
        extra_parts_expr = _SimWS._remember_extra_parts_expr(parsed_args[1])
        parsed_args = parsed_args[2:end]
        isempty(parsed_args) && error("@simos remember extra key tuple must be followed by a target.")
    end
    length(parsed_args) in (1, 2) || error("@simos remember expects `@simos remember h target begin ... end`, `@simos remember h target = expr`, or the same with an extra key tuple before `target`.")

    local target_expr
    local payload_expr
    local mode

    if length(parsed_args) == 1
        arg = parsed_args[1]
        if !(arg isa Expr && arg.head == :(=) && length(arg.args) == 2)
            error("@simos remember single-tail form expects assignment: `@simos remember h target = expr`.")
        end
        target_expr = arg.args[1]
        payload_expr = arg.args[2]
        mode = :assign
    else
        target_expr = parsed_args[1]
        payload_expr = parsed_args[2]
        mode = :block
    end

    vars = _SimWS._remember_target_vars(target_expr)
    ns_expr = length(vars) == 1 ?
        :($(_SimWS)._remember_namespace($(QuoteNode(vars[1])))) :
        :($(_SimWS)._remember_namespace(Symbol[$([QuoteNode(v) for v in vars]...)]))

    hit_assign_expr = length(vars) == 1 ?
        _SimWS._remember_assign_expr(vars[1], :_remember_cached_value) :
        _SimWS._remember_assign_expr(vars, :_remember_cached_value)
    miss_value_expr = length(vars) == 1 ? _SimWS._remember_value_expr(vars[1]) : _SimWS._remember_value_expr(vars)
    defined_checks = _SimWS._remember_defined_checks(vars)
    composed_ctx_expr = isnothing(extra_parts_expr) ?
        :(string($ctx_hash_expr)) :
        :($(_SimWS)._ctx_hash_compose(string($ctx_hash_expr), $extra_parts_expr))
    store_input_expr = mode == :assign ? :_remember_miss_value : miss_value_expr
    final_assign_expr = _SimWS._remember_assign_expr(length(vars) == 1 ? vars[1] : vars, :_remember_final_value)

    miss_store_expr = Expr(:block,
        :(local _remember_final_value, _remember_miss_status),
        :((_remember_final_value, _remember_miss_status) = $(_SimWS)._remember_store_result!(_remember_ns, _remember_ctx_hash, $store_input_expr)),
        final_assign_expr,
        :(_remember_miss_status),
    )

    miss_branch_expr = if mode == :assign
        miss_store_expr
    else
        Expr(:block,
            payload_expr,
            defined_checks...,
            miss_store_expr,
        )
    end

    return quote
        local _remember_ctx_hash = $composed_ctx_expr
        local _remember_ns = $ns_expr
        local _remember_hit, _remember_cached_value = $(_SimWS)._remember_tryload(_remember_ns, _remember_ctx_hash)
        if _remember_hit
            $hit_assign_expr
            $(QuoteNode(:hit))
        else
            $(mode == :assign ? :(local _remember_miss_value = $payload_expr) : nothing)
            $miss_branch_expr
        end
    end
end

function _simos_expand(mod, src, args)
    length(args) >= 3 || error("@simos expand expects scope, project, and at least one variable name.")
    scope_expr = args[1]
    project_expr = args[2]
    var_names = args[3:end]

    for v in var_names
        v isa Symbol || error("@simos expand expects variable names, got: $v")
    end

    scope_in = esc(scope_expr)
    project_in = esc(project_expr)
    caller_module = QuoteNode(mod)

    stmts = Expr[]
    for v in var_names
        name = QuoteNode(v)
        level_sym = gensym(:scope_expand_level)
        value_sym = gensym(:scope_expand_value)
        push!(stmts, quote
            local $level_sym, $value_sym
            $level_sym, $value_sym = $(_SimSR)._scope_expand_runtime!($scope_in, $project_in, $name)
            if $level_sym === :global
                $(_SimSR)._scope_expand_setglobal!($caller_module, $name, $value_sym)
            elseif $level_sym === :local
                $(esc(v)) = $value_sym
            else
                error("Unsupported scope level `$($level_sym)` for variable `$(string($name))`.")
            end
        end)
    end

    # expand handler returns pre-escaped stmts, so the dispatcher must not double-esc
    # We signal this by wrapping in a special marker — but simpler: just return the block
    # and have the dispatcher handle esc uniformly.
    # Actually, expand is special because it uses esc() internally on scope_in/project_in/v.
    # We need to NOT esc the whole thing again. Let's use a different approach:
    # Return a :__simos_raw_expr__ wrapper that the dispatcher checks for.
    return Expr(:__simos_raw_expr__, Expr(:block, stmts...))
end

# ------------------------------------------------------------------
# Dispatcher macro
# ------------------------------------------------------------------

"""
    @simos verb args...

Unified dispatch macro for Simuleos. Routes to the appropriate handler
based on the verb subcommand.

## Verbs

| Verb | Equivalent old macro |
|---|---|
| `init` | `@session_init` |
| `store` | `@store_blob` |
| `hash` | `@store_hash` |
| `inline` | `@scope_inline` |
| `meta` | `@scope_meta` |
| `capture` | `@scope_capture` |
| `commit` | `@session_commit` |
| `batch_commit` | `@session_batch_commit` |
| `finalize` | `@session_finalize` |
| `ctx_hash` | `@ctx_hash` |
| `remember` | `@remember` |
| `expand` | `@scope_expand` |
"""
macro simos(verb, rest...)
    verb isa Symbol || error("@simos expects a verb symbol as first argument. Valid verbs: $(_simos_verb_list_str())")

    local result_expr
    if verb === :init
        result_expr = _simos_init(__module__, __source__, rest)
    elseif verb === :store
        result_expr = _simos_store(__module__, __source__, rest)
    elseif verb === :hash
        result_expr = _simos_hash(__module__, __source__, rest)
    elseif verb === :inline
        result_expr = _simos_inline(__module__, __source__, rest)
    elseif verb === :meta
        result_expr = _simos_meta(__module__, __source__, rest)
    elseif verb === :capture
        result_expr = _simos_capture(__module__, __source__, rest)
    elseif verb === :commit
        result_expr = _simos_commit(__module__, __source__, rest)
    elseif verb === :batch_commit
        result_expr = _simos_batch_commit(__module__, __source__, rest)
    elseif verb === :finalize
        result_expr = _simos_finalize(__module__, __source__, rest)
    elseif verb === :ctx_hash
        result_expr = _simos_ctx_hash(__module__, __source__, rest)
    elseif verb === :remember
        result_expr = _simos_remember(__module__, __source__, rest)
    elseif verb === :expand
        result_expr = _simos_expand(__module__, __source__, rest)
    else
        error("Unknown @simos verb `$(verb)`. Valid verbs: $(_simos_verb_list_str())")
    end

    # expand handler returns pre-escaped expressions (it uses esc() internally)
    if result_expr isa Expr && result_expr.head === :__simos_raw_expr__
        return result_expr.args[1]
    end

    return esc(result_expr)
end
