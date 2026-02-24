# ============================================================
# SimosAPI/macro.jl — Unified @simos dispatch macro
# ============================================================

const _SimWS = WorkSession
const _SimSR = ScopeReader
const _SimKrn = Kernel
const _SimosAPI = SimosAPI

"""
    SIMOS_GLOBAL_LOCK

Process-wide reentrant lock serializing all `@simos` operations.
Acts as a GIL: every `@simos` call acquires this lock before
executing, ensuring thread-safe access to `SIMOS[]` and all
`WorkSession` / `ScopeStage` mutable state.
"""
const SIMOS_GLOBAL_LOCK = ReentrantLock()

"""
    SIMOS_GLOBAL_LOCK_ENABLED

Runtime flag controlling whether `@simos` acquires `SIMOS_GLOBAL_LOCK`.
Set to `false` to disable locking (e.g., single-threaded workloads).
Default: `true`.
"""
const SIMOS_GLOBAL_LOCK_ENABLED = Ref(true)

const _SIMOS_COMMANDS = (
    (:system, :init),
    (:system, :reset),
    (:project, :current),
    (:blob, :meta),
    (:session, :init),
    (:session, :commit),
    (:session, :queue),
    (:session, :close),
    (:stage, :blob),
    (:stage, :hash),
    (:stage, :inline),
    (:stage, :meta),
    (:scope, :capture),
    (:scope, :bind),
    (:shared, :capture),
    (:shared, :bind),
    (:shared, :merge),
    (:shared, :keys),
    (:shared, :has),
    (:shared, :drop),
    (:shared, :clear),
    (:cache, :key),
    (:cache, :remember),
)

function _simos_command_list_str()
    return join((_simos_path_str(cmd) for cmd in _SIMOS_COMMANDS), ", ")
end

function _simos_path_str(path)::String
    return join(string.(path), ".")
end

function _simos_parse_command_path(expr)
    if expr isa Symbol
        return Symbol[expr]
    end
    if expr isa Expr && expr.head === :. && length(expr.args) == 2
        left = _simos_parse_command_path(expr.args[1])
        right = expr.args[2]
        name = right isa QuoteNode ? right.value : right
        name isa Symbol || error("@simos command path segments must be symbols, got: $right")
        push!(left, name)
        return left
    end
    error("@simos expects a dotted command path like `session.init`, got: $expr")
end

function _simos_parse_do_payload(expr)
    if !(expr isa Expr && expr.head === :-> && length(expr.args) == 2)
        error("@simos do form expects `do ... end` without arguments.")
    end
    params = expr.args[1]
    if !(params isa Expr && params.head === :tuple && isempty(params.args))
        error("@simos do block must not declare arguments.")
    end
    return expr.args[2]
end

function _simos_split_call(call_expr)
    call_expr isa Expr && call_expr.head === :call || error("@simos expects call-style syntax: `@simos group.command(...)`")

    path = Tuple(_simos_parse_command_path(call_expr.args[1]))
    posargs = Any[]
    kwargs = Expr[]
    for arg in call_expr.args[2:end]
        if arg isa Expr && arg.head === :parameters
            for kw in arg.args
                kw isa Expr && kw.head === :kw && length(kw.args) == 2 && kw.args[1] isa Symbol ||
                    error("@simos keyword arguments must be `name=value`, got: $kw")
                push!(kwargs, kw)
            end
        elseif arg isa Expr && arg.head === :kw
            length(arg.args) == 2 && arg.args[1] isa Symbol ||
                error("@simos keyword arguments must be `name=value`, got: $arg")
            push!(kwargs, arg)
        else
            push!(posargs, arg)
        end
    end

    return path, posargs, kwargs
end

function _simos_parse_invocation(invocation_expr)
    payload_expr = nothing
    call_expr = invocation_expr
    if invocation_expr isa Expr && invocation_expr.head === :do
        length(invocation_expr.args) == 2 || error("@simos do syntax parse error.")
        call_expr = invocation_expr.args[1]
        payload_expr = _simos_parse_do_payload(invocation_expr.args[2])
    end

    path, posargs, kwargs = _simos_split_call(call_expr)
    return path, posargs, kwargs, payload_expr
end

function _simos_kw_to_assign(kw::Expr)
    kw.head === :kw && length(kw.args) == 2 && kw.args[1] isa Symbol ||
        error("@simos internal error: expected keyword expr, got: $kw")
    return Expr(:(=), kw.args[1], kw.args[2])
end

function _simos_kwargs_tuple_expr(kwargs::Vector{Expr})
    assigns = [_simos_kw_to_assign(kw) for kw in kwargs]
    return Expr(:tuple, assigns...)
end

"""
    _simos_extract_sgl_kwarg!(kwargs) -> Union{Bool, Nothing}

Pop `sgl=true/false` from kwargs if present. Returns `true`, `false`,
or `nothing` (no per-call override, defer to global flag).
"""
function _simos_extract_sgl_kwarg!(kwargs::Vector{Expr})
    idx = findfirst(kwargs) do kw
        kw.head === :kw && kw.args[1] === :sgl
    end
    isnothing(idx) && return nothing
    val = kwargs[idx].args[2]
    val isa Bool || error("@simos `sgl` option must be a literal `true` or `false`, got: $val")
    deleteat!(kwargs, idx)
    return val
end

function _simos_disallow_kwargs(path, kwargs)
    isempty(kwargs) || error("@simos $(_simos_path_str(path)) does not accept keyword arguments.")
end

function _simos_disallow_do(path, payload_expr)
    isnothing(payload_expr) || error("@simos $(_simos_path_str(path)) does not accept a `do` block.")
end

function _simos_dispatch_call(mod, src, path::Tuple, posargs::Vector{Any}, kwargs::Vector{Expr}, payload_expr)
    if path == (:system, :init)
        _simos_disallow_do(path, payload_expr)
        isempty(posargs) || error("@simos system.init is engine-only and does not accept session labels. Use `@simos session.init(...)`.")
        args = Any[_simos_kw_to_assign.(kwargs)...]
        return _simos_init(mod, src, args)
    elseif path == (:system, :reset)
        _simos_disallow_do(path, payload_expr)
        isempty(posargs) || error("@simos system.reset accepts only keyword arguments.")
        args = Any[_simos_kw_to_assign.(kwargs)...]
        return _simos_reset(mod, src, args)
    elseif path == (:project, :current)
        _simos_disallow_kwargs(path, kwargs)
        _simos_disallow_do(path, payload_expr)
        isempty(posargs) || error("@simos project.current accepts no positional arguments.")
        return _simos_project_current(mod, src)
    elseif path == (:blob, :meta)
        _simos_disallow_kwargs(path, kwargs)
        _simos_disallow_do(path, payload_expr)
        return _simos_blob_meta(mod, src, posargs)
    elseif path == (:session, :init)
        _simos_disallow_kwargs(path, kwargs)
        _simos_disallow_do(path, payload_expr)
        return _simos_session_init(mod, src, posargs)
    elseif path == (:session, :commit)
        _simos_disallow_kwargs(path, kwargs)
        _simos_disallow_do(path, payload_expr)
        return _simos_commit(mod, src, posargs)
    elseif path == (:session, :queue)
        _simos_disallow_do(path, payload_expr)
        return _simos_batch_commit(mod, src, posargs, kwargs)
    elseif path == (:session, :close)
        _simos_disallow_kwargs(path, kwargs)
        _simos_disallow_do(path, payload_expr)
        return _simos_finalize(mod, src, posargs)
    elseif path == (:stage, :blob)
        _simos_disallow_kwargs(path, kwargs)
        _simos_disallow_do(path, payload_expr)
        return _simos_store(mod, src, posargs)
    elseif path == (:stage, :hash)
        _simos_disallow_kwargs(path, kwargs)
        _simos_disallow_do(path, payload_expr)
        return _simos_hash(mod, src, posargs)
    elseif path == (:stage, :inline)
        _simos_disallow_kwargs(path, kwargs)
        _simos_disallow_do(path, payload_expr)
        return _simos_inline(mod, src, posargs)
    elseif path == (:stage, :meta)
        _simos_disallow_do(path, payload_expr)
        isempty(posargs) || error("@simos stage.meta accepts only keyword arguments.")
        return _simos_meta(mod, src, Any[_simos_kw_to_assign.(kwargs)...])
    elseif path == (:scope, :capture)
        _simos_disallow_kwargs(path, kwargs)
        _simos_disallow_do(path, payload_expr)
        return _simos_capture(mod, src, posargs)
    elseif path == (:scope, :bind)
        _simos_disallow_kwargs(path, kwargs)
        _simos_disallow_do(path, payload_expr)
        return _simos_expand(mod, src, posargs)
    elseif path == (:shared, :capture)
        _simos_disallow_kwargs(path, kwargs)
        _simos_disallow_do(path, payload_expr)
        return _simos_shared_capture(mod, src, posargs)
    elseif path == (:shared, :bind)
        _simos_disallow_kwargs(path, kwargs)
        _simos_disallow_do(path, payload_expr)
        return _simos_shared_bind(mod, src, posargs)
    elseif path == (:shared, :merge)
        _simos_disallow_kwargs(path, kwargs)
        _simos_disallow_do(path, payload_expr)
        return _simos_shared_merge(mod, src, posargs)
    elseif path == (:shared, :keys)
        _simos_disallow_kwargs(path, kwargs)
        _simos_disallow_do(path, payload_expr)
        return _simos_shared_keys(mod, src, posargs)
    elseif path == (:shared, :has)
        _simos_disallow_kwargs(path, kwargs)
        _simos_disallow_do(path, payload_expr)
        return _simos_shared_has(mod, src, posargs)
    elseif path == (:shared, :drop)
        _simos_disallow_kwargs(path, kwargs)
        _simos_disallow_do(path, payload_expr)
        return _simos_shared_drop(mod, src, posargs)
    elseif path == (:shared, :clear)
        _simos_disallow_kwargs(path, kwargs)
        _simos_disallow_do(path, payload_expr)
        return _simos_shared_clear(mod, src, posargs)
    elseif path == (:cache, :key)
        _simos_disallow_do(path, payload_expr)
        args = Any[posargs...]
        append!(args, _simos_kw_to_assign.(kwargs))
        return _simos_ctx_hash(mod, src, args)
    elseif path == (:cache, :remember)
        length(posargs) in (2, 3) || error("@simos cache.remember expects `(ctx_hash, target)` plus a `do` block or explicit payload expression.")
        ctx_hash_expr = posargs[1]
        target_expr = posargs[2]
        if !isnothing(payload_expr) && length(posargs) != 2
            error("@simos cache.remember do form expects exactly `(ctx_hash, target)` positional arguments.")
        end
        if isnothing(payload_expr) && length(posargs) == 2
            error("@simos cache.remember requires a `do` block or an explicit third payload expression.")
        end
        payload = isnothing(payload_expr) ? posargs[3] : payload_expr

        args = Any[ctx_hash_expr]
        isempty(kwargs) || push!(args, _simos_kwargs_tuple_expr(kwargs))
        push!(args, Expr(:(=), target_expr, payload))
        return _simos_remember(mod, src, args)
    else
        error("Unknown @simos command `$(_simos_path_str(path))`. Valid commands: $(_simos_command_list_str())")
    end
end

# ------------------------------------------------------------------
# Handlers — each returns an Expr (already esc'd by dispatcher)
# ------------------------------------------------------------------

function _simos_init(mod, src, args)
    src_file = string(src.file)
    src_line = src.line

    opts = Dict{Symbol, Any}()
    for arg in args
        if arg isa Expr && arg.head == :(=) && length(arg.args) == 2 && arg.args[1] isa Symbol
            key = arg.args[1]
            val = arg.args[2]
            key in (:bootstrap, :sandbox, :reinit, :sandbox_cleanup) ||
                error("@simos system.init unknown option `$(key)`. Valid options: bootstrap, sandbox, reinit, sandbox_cleanup.")
            haskey(opts, key) && error("@simos system.init duplicate option `$(key)`.")
            opts[key] = val
        else
            error("@simos system.init is engine-only and does not accept session labels. Use `@simos session.init(...)`.")
        end
    end

    bootstrap_expr = get(opts, :bootstrap, :(nothing))
    sandbox_expr = get(opts, :sandbox, :(nothing))
    reinit_expr = get(opts, :reinit, false)
    sandbox_cleanup_expr = get(opts, :sandbox_cleanup, QuoteNode(:auto))

    return quote
        $(_SimWS).engine_init_from_macro!($src_file, $src_line;
            bootstrap = $(bootstrap_expr),
            sandbox = $(sandbox_expr),
            reinit = $(reinit_expr),
            sandbox_cleanup = $(sandbox_cleanup_expr),
        )
    end
end

function _simos_session_init(mod, src, args)
    src_file = string(src.file)
    src_line = src.line
    return quote
        $(_SimWS).session_init_from_macro!(Any[$(args...)], $src_file, $src_line)
    end
end

function _simos_reset(mod, src, args)
    _ = mod
    _ = src

    opts = Dict{Symbol, Any}()
    for arg in args
        if !(arg isa Expr && arg.head == :(=) && length(arg.args) == 2 && arg.args[1] isa Symbol)
            error("@simos system.reset accepts only keyword arguments (e.g. `sandbox_cleanup=:delete`).")
        end
        key = arg.args[1]
        val = arg.args[2]
        key in (:sandbox_cleanup,) ||
            error("@simos system.reset unknown option `$(key)`. Valid options: sandbox_cleanup.")
        haskey(opts, key) && error("@simos system.reset duplicate option `$(key)`.")
        opts[key] = val
    end

    sandbox_cleanup_expr = get(opts, :sandbox_cleanup, QuoteNode(:auto))

    return quote
        $(_SimKrn).sim_reset!(; sandbox_cleanup = $(sandbox_cleanup_expr))
    end
end

function _simos_project_current(mod, src)
    _ = mod
    _ = src
    return quote
        $(_SimKrn).sim_project()
    end
end

function _simos_blob_meta(mod, src, args)
    _ = mod
    _ = src
    length(args) == 1 || error("@simos blob.meta expects exactly one positional argument (blob ref/hash/key).")
    lookup_expr = args[1]
    return quote
        $(_SimKrn).blob_metadata($(_SimKrn)._get_sim(), $(lookup_expr))
    end
end

function _simos_store(mod, src, args)
    stmts = Expr[]
    for v in args
        v isa Symbol || error("@simos store expects variable names, got: $v")
        push!(stmts, quote
            let sim = $(_SimKrn)._get_sim()
                isnothing(sim.worksession) && error("No active session. Call `@simos session.init(...)` first.")
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
                isnothing(sim.worksession) && error("No active session. Call `@simos session.init(...)` first.")
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
                isnothing(sim.worksession) && error("No active session. Call `@simos session.init(...)` first.")
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
                    isnothing(sim.worksession) && error("No active session. Call `@simos session.init(...)` first.")
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

function _simos_batch_commit(mod, src, args, kwargs::Vector{Expr}=Expr[])
    label_expr = isempty(args) ? "" : args[1]
    if isempty(kwargs)
        return quote
            $(_SimWS).session_batch_commit(string($label_expr))
        end
    end
    return quote
        $(_SimWS).session_batch_commit(string($label_expr); $(kwargs...))
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

function _simos_parse_bind_spec(cmd::AbstractString, arg)
    if arg isa Symbol
        return (name = arg, type_expr = nothing)
    end
    if arg isa Expr && arg.head == :(::) && length(arg.args) == 2 && arg.args[1] isa Symbol
        return (name = arg.args[1], type_expr = arg.args[2])
    end
    error("$(cmd) expects variable names or typed bindings (`x` or `x::T`), got: $arg")
end

function _simos_bind_value_expr(value_sym::Symbol, type_expr)
    if isnothing(type_expr)
        return value_sym
    end
    return :((convert($(type_expr), $(value_sym))::$(type_expr)))
end

function _simos_bind_assign_expr(var::Symbol, value_expr, type_expr)
    _ = type_expr
    return :($(var) = $(value_expr))
end

function _simos_bind_from_scope(mod, scope_expr, project_expr, bind_args, cmd::AbstractString)
    isempty(bind_args) && error("$(cmd) expects at least one variable name.")
    bind_specs = [_simos_parse_bind_spec(cmd, arg) for arg in bind_args]

    scope_in = scope_expr
    project_in = project_expr
    caller_module = QuoteNode(mod)

    stmts = Expr[]
    for spec in bind_specs
        v = spec.name
        type_expr = spec.type_expr
        name = QuoteNode(v)
        level_sym = gensym(:scope_expand_level)
        value_sym = gensym(:scope_expand_value)
        bound_value_expr = _simos_bind_value_expr(value_sym, type_expr)
        local_assign_expr = _simos_bind_assign_expr(v, bound_value_expr, type_expr)
        push!(stmts, quote
            local $level_sym, $value_sym
            $level_sym, $value_sym = $(_SimSR)._scope_expand_runtime!($scope_in, $project_in, $name)
            if $level_sym === :global
                $(_SimSR)._scope_expand_setglobal!($caller_module, $name, $bound_value_expr)
            elseif $level_sym === :local || $level_sym === :shared
                $local_assign_expr
            else
                error("Unsupported scope level `$($level_sym)` for variable `$(string($name))`.")
            end
        end)
    end

    return Expr(:block, stmts...)
end

function _simos_expand(mod, src, args)
    _ = src
    length(args) >= 3 || error("@simos scope.bind expects scope, project, and at least one variable name.")
    scope_expr = args[1]
    project_expr = args[2]
    bind_args = args[3:end]
    return _simos_bind_from_scope(mod, scope_expr, project_expr, bind_args, "@simos scope.bind")
end

function _simos_shared_capture(mod, src, args)
    isempty(args) && error("@simos shared.capture expects a shared key and optional variable names.")
    key_expr = args[1]
    selected_args = args[2:end]
    for v in selected_args
        v isa Symbol || error("@simos shared.capture selected values must be variable names, got: $v")
    end

    names_expr = isempty(selected_args) ?
        :(nothing) :
        :(Symbol[$([QuoteNode(v) for v in selected_args]...)])

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

            $(_SimWS).shared_capture(
                string($key_expr),
                _locals,
                _globals,
                $src_file,
                $src_line;
                names = $names_expr,
            )
        end
    end
end

function _simos_shared_bind(mod, src, args)
    _ = src
    length(args) >= 2 || error("@simos shared.bind expects a shared key and at least one variable name.")
    key_expr = args[1]
    bind_args = args[2:end]
    scope_expr = :($(_SimWS).shared_get(string($key_expr)))
    return _simos_bind_from_scope(mod, scope_expr, :(nothing), bind_args, "@simos shared.bind")
end

function _simos_shared_merge(mod, src, args)
    _ = mod
    _ = src
    length(args) == 2 || error("@simos shared.merge expects exactly `(dest_key, src_key)`.")
    dest_expr = args[1]
    src_expr = args[2]
    return quote
        $(_SimWS).shared_merge!(string($dest_expr), string($src_expr))
    end
end

function _simos_shared_keys(mod, src, args)
    _ = mod
    _ = src
    isempty(args) || error("@simos shared.keys expects no positional arguments.")
    return quote
        $(_SimWS).shared_keys()
    end
end

function _simos_shared_has(mod, src, args)
    _ = mod
    _ = src
    length(args) == 1 || error("@simos shared.has expects exactly one key.")
    key_expr = args[1]
    return quote
        $(_SimWS).shared_has(string($key_expr))
    end
end

function _simos_shared_drop(mod, src, args)
    _ = mod
    _ = src
    length(args) == 1 || error("@simos shared.drop expects exactly one key.")
    key_expr = args[1]
    return quote
        $(_SimWS).shared_drop!(string($key_expr))
    end
end

function _simos_shared_clear(mod, src, args)
    _ = mod
    _ = src
    isempty(args) || error("@simos shared.clear expects no positional arguments.")
    return quote
        $(_SimWS).shared_clear!()
    end
end

# ------------------------------------------------------------------
# Dispatcher macro
# ------------------------------------------------------------------

"""
    @simos system.init(...)
    @simos system.reset(...)
    @simos group.command(...)
    @simos cache.remember(...) do
        ...
    end

Unified dispatch macro for Simuleos. Uses a dotted command path plus normal
call syntax so the command path is clearly separated from the arguments.

## Commands

| Command | Description |
|---|---|
| `system.init` | Engine init/reinit |
| `system.reset` | Reset engine state |
| `project.current` | Active `SimuleosProject` |
| `blob.meta` | Latest metadata record for a blob |
| `session.init` | Initialize a work session |
| `session.commit` | Commit staged scopes |
| `session.queue` | Queue a batch commit |
| `session.close` | Finalize and flush session |
| `stage.blob` | Mark variables for blob storage |
| `stage.hash` | Mark variables for hash-only storage |
| `stage.inline` | Mark variables for inline storage |
| `stage.meta` | Set stage metadata key-value pairs |
| `scope.capture` | Capture local/global variables |
| `scope.bind` | Bind scope variables into caller |
| `shared.capture` | Capture vars into in-memory shared scope |
| `shared.bind` | Bind vars from in-memory shared scope |
| `shared.merge` | Merge shared scope variables (shallow overwrite) |
| `shared.keys` | List shared scope keys |
| `shared.has` | Check if shared scope key exists |
| `shared.drop` | Delete one shared scope key |
| `shared.clear` | Clear shared scope registry |
| `cache.key` | Compute a named context hash |
| `cache.remember` | Cache-or-compute with context hash |
"""
macro simos(invocation...)
    local result_expr
    if length(invocation) == 1 && invocation[1] isa Expr &&
            (((invocation[1])::Expr).head === :call || ((invocation[1])::Expr).head === :do)
        path, posargs, kwargs, payload_expr = _simos_parse_invocation(invocation[1])
        # Extract per-call `sgl` kwarg before dispatch
        sgl_enabled = _simos_extract_sgl_kwarg!(kwargs)
        result_expr = _simos_dispatch_call(__module__, __source__, path, posargs, kwargs, payload_expr)
    else
        error("@simos expects call-style syntax like `@simos system.command(args...; kwargs...)`. Valid commands: $(_simos_command_list_str())")
    end
    # SGL: serialize all @simos operations under SIMOS_GLOBAL_LOCK
    if sgl_enabled === true
        # sgl=true: always lock regardless of global flag
        locked_expr = quote
            @lock $(_SimosAPI).SIMOS_GLOBAL_LOCK begin
                $(result_expr)
            end
        end
    elseif sgl_enabled === false
        # sgl=false: never lock regardless of global flag
        locked_expr = result_expr
    else
        # no per-call override: defer to global flag
        locked_expr = quote
            if $(_SimosAPI).SIMOS_GLOBAL_LOCK_ENABLED[]
                @lock $(_SimosAPI).SIMOS_GLOBAL_LOCK begin
                    $(result_expr)
                end
            else
                $(result_expr)
            end
        end
    end
    return esc(locked_expr)
end
