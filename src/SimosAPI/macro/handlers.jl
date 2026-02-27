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

function _simos_validate_kwargs(cmd::String, kwargs::Vector{Expr}, allowed::Tuple)
    allowed_str = join(string.(allowed), ", ")
    seen = Set{Symbol}()
    for kw in kwargs
        kw isa Expr && kw.head === :kw && length(kw.args) == 2 && kw.args[1] isa Symbol ||
            error("@simos $(cmd) internal parse error: expected keyword expr, got: $kw")
        key = kw.args[1]
        key in allowed ||
            error("@simos $(cmd) unknown option `$(key)`. Valid options: $(allowed_str).")
        key in seen && error("@simos $(cmd) duplicate option `$(key)`.")
        push!(seen, key)
    end
    return nothing
end

function _simos_require_arg_count(args::Vector{Any}, expected::Int, error_msg::AbstractString)
    length(args) == expected || error(error_msg)
    return nothing
end

function _simos_prepare_call_args(args::Vector{Any}; stringify_idxs::Tuple = ())
    call_args = Any[]
    for (idx, arg) in pairs(args)
        if idx in stringify_idxs
            push!(call_args, :(string($(arg))))
        else
            push!(call_args, arg)
        end
    end
    return call_args
end

function _simos_emit_runtime_call(runtime_expr, call_args::Vector{Any}, kwargs::Vector{Expr}; keyword_only::Bool = false)
    if keyword_only
        isempty(call_args) || error("@simos internal error: keyword-only runtime call received positional args.")
        if isempty(kwargs)
            return quote
                $(runtime_expr)()
            end
        end
        return quote
            $(runtime_expr)(; $(kwargs...))
        end
    end

    if isempty(kwargs)
        return quote
            $(runtime_expr)($(call_args...))
        end
    end
    return quote
        $(runtime_expr)($(call_args...); $(kwargs...))
    end
end

function _simos_settings_runtime_handler(
        cmd::String,
        runtime_expr,
        args::Vector{Any},
        kwargs::Vector{Expr};
        expected_arity::Union{Int, Nothing} = nothing,
        arity_error::Union{String, Nothing} = nothing,
        allowed_kwargs::Tuple = (),
        stringify_arg_idxs::Tuple = (),
        keyword_only::Bool = false,
    )
    if !isnothing(expected_arity)
        err = isnothing(arity_error) ?
            "@simos $(cmd) expects exactly $(expected_arity) positional arguments." :
            arity_error
        _simos_require_arg_count(args, expected_arity, err)
    end
    _simos_validate_kwargs(cmd, kwargs, allowed_kwargs)

    call_args = _simos_prepare_call_args(args; stringify_idxs = stringify_arg_idxs)
    return _simos_emit_runtime_call(runtime_expr, call_args, kwargs; keyword_only = keyword_only)
end

function _simos_settings_get(mod, src, args, kwargs::Vector{Expr}=Expr[])
    _ = mod
    _ = src
    return _simos_settings_runtime_handler(
        "settings.get",
        :($(_SimosAPI)._simos_settings_get_runtime),
        args,
        kwargs;
        expected_arity = 1,
        arity_error = "@simos settings.get expects exactly one key.",
        allowed_kwargs = (:default, :layer),
        stringify_arg_idxs = (1,),
    )
end

function _simos_settings_has(mod, src, args, kwargs::Vector{Expr}=Expr[])
    _ = mod
    _ = src
    return _simos_settings_runtime_handler(
        "settings.has",
        :($(_SimosAPI)._simos_settings_has_runtime),
        args,
        kwargs;
        expected_arity = 1,
        arity_error = "@simos settings.has expects exactly one key.",
        allowed_kwargs = (:layer,),
        stringify_arg_idxs = (1,),
    )
end

function _simos_settings_require(mod, src, args, kwargs::Vector{Expr}=Expr[])
    _ = mod
    _ = src
    return _simos_settings_runtime_handler(
        "settings.require",
        :($(_SimosAPI)._simos_settings_require_runtime),
        args,
        kwargs;
        expected_arity = 1,
        arity_error = "@simos settings.require expects exactly one key.",
        allowed_kwargs = (:layer,),
        stringify_arg_idxs = (1,),
    )
end

function _simos_settings_explain(mod, src, args, kwargs::Vector{Expr}=Expr[])
    _ = mod
    _ = src
    return _simos_settings_runtime_handler(
        "settings.explain",
        :($(_SimosAPI)._simos_settings_explain_runtime),
        args,
        kwargs;
        expected_arity = 1,
        arity_error = "@simos settings.explain expects exactly one key.",
        allowed_kwargs = (:layer,),
        stringify_arg_idxs = (1,),
    )
end

function _simos_settings_layers(mod, src)
    _ = mod
    _ = src
    return quote
        $(_SimosAPI)._simos_settings_layers_runtime()
    end
end

function _simos_settings_snapshot(mod, src, kwargs::Vector{Expr}=Expr[])
    _ = mod
    _ = src
    return _simos_settings_runtime_handler(
        "settings.snapshot",
        :($(_SimosAPI)._simos_settings_snapshot_runtime),
        Any[],
        kwargs;
        allowed_kwargs = (:layer, :prefix, :nested),
        keyword_only = true,
    )
end

function _simos_settings_set(mod, src, args, kwargs::Vector{Expr}=Expr[])
    _ = mod
    _ = src
    return _simos_settings_runtime_handler(
        "settings.set",
        :($(_SimosAPI)._simos_settings_set_runtime),
        args,
        kwargs;
        expected_arity = 2,
        arity_error = "@simos settings.set expects exactly `(key, value)`.",
        allowed_kwargs = (:layer,),
        stringify_arg_idxs = (1,),
    )
end

function _simos_settings_unset(mod, src, args, kwargs::Vector{Expr}=Expr[])
    _ = mod
    _ = src
    return _simos_settings_runtime_handler(
        "settings.unset",
        :($(_SimosAPI)._simos_settings_unset_runtime),
        args,
        kwargs;
        expected_arity = 1,
        arity_error = "@simos settings.unset expects exactly one key.",
        allowed_kwargs = (:layer,),
        stringify_arg_idxs = (1,),
    )
end

function _simos_settings_merge(mod, src, args, kwargs::Vector{Expr}=Expr[])
    _ = mod
    _ = src
    return _simos_settings_runtime_handler(
        "settings.merge",
        :($(_SimosAPI)._simos_settings_merge_runtime),
        args,
        kwargs;
        expected_arity = 1,
        arity_error = "@simos settings.merge expects exactly one dict payload.",
        allowed_kwargs = (:layer, :clear),
    )
end

function _simos_settings_clear(mod, src, kwargs::Vector{Expr}=Expr[])
    _ = mod
    _ = src
    return _simos_settings_runtime_handler(
        "settings.clear",
        :($(_SimosAPI)._simos_settings_clear_runtime),
        Any[],
        kwargs;
        allowed_kwargs = (:layer, :prefix),
        keyword_only = true,
    )
end

function _simos_settings_source_add_json(mod, src, args, kwargs::Vector{Expr}=Expr[])
    _ = mod
    _ = src
    return _simos_settings_runtime_handler(
        "settings.source.add_json",
        :($(_SimosAPI)._simos_settings_source_add_json_runtime),
        args,
        kwargs;
        expected_arity = 1,
        arity_error = "@simos settings.source.add_json expects exactly one path.",
        allowed_kwargs = (:name, :after, :optional, :replace),
        stringify_arg_idxs = (1,),
    )
end

function _simos_settings_source_add_args(mod, src, args, kwargs::Vector{Expr}=Expr[])
    _ = mod
    _ = src
    return _simos_settings_runtime_handler(
        "settings.source.add_args",
        :($(_SimosAPI)._simos_settings_source_add_args_runtime),
        args,
        kwargs;
        expected_arity = 1,
        arity_error = "@simos settings.source.add_args expects exactly one argument (Vector{String}).",
        allowed_kwargs = (:after,),
    )
end

function _simos_settings_source_reload(mod, src, args, kwargs::Vector{Expr}=Expr[])
    _ = mod
    _ = src
    _simos_disallow_kwargs((:settings, :source, :reload), kwargs)
    length(args) <= 1 || error("@simos settings.source.reload expects no arguments or one source name.")
    if isempty(args)
        return quote
            $(_SimosAPI)._simos_settings_source_reload_runtime()
        end
    end
    name_expr = args[1]
    return quote
        $(_SimosAPI)._simos_settings_source_reload_runtime($(name_expr))
    end
end

function _simos_settings_source_remove(mod, src, args)
    _ = mod
    _ = src
    length(args) == 1 || error("@simos settings.source.remove expects exactly one source name.")
    name_expr = args[1]
    return quote
        $(_SimosAPI)._simos_settings_source_remove_runtime($(name_expr))
    end
end

function _simos_settings_source_list(mod, src)
    _ = mod
    _ = src
    return quote
        $(_SimosAPI)._simos_settings_source_list_runtime()
    end
end

function _simos_settings_registry_register(mod, src, args, kwargs::Vector{Expr}=Expr[])
    _ = mod
    _ = src
    _simos_require_arg_count(args, 2, "@simos settings.registry.register expects exactly `(canonical_key, spec)`.")
    _simos_validate_kwargs("settings.registry.register", kwargs, (:replace,))

    call_args = Any[
        :($(_SimKrn)._get_sim()),
        :(string($(args[1]))),
        args[2],
    ]
    return _simos_emit_runtime_call(:($(_SimKrn).settings_registry_register!), call_args, kwargs)
end

function _simos_settings_registry_unregister(mod, src, args)
    _ = mod
    _ = src
    length(args) == 1 || error("@simos settings.registry.unregister expects exactly one key or alias.")
    key_expr = args[1]
    return quote
        $(_SimKrn).settings_registry_unregister!($(_SimKrn)._get_sim(), string($(key_expr)))
    end
end

function _simos_settings_registry_list(mod, src)
    _ = mod
    _ = src
    return quote
        $(_SimKrn).settings_registry_list($(_SimKrn)._get_sim())
    end
end

function _simos_sqlite_path(mod, src)
    _ = mod
    _ = src
    return quote
        $(_SimosAPI)._simos_sqlite_path_runtime()
    end
end

function _simos_sqlite_open(mod, src, kwargs::Vector{Expr}=Expr[])
    _ = mod
    _ = src
    seen = Set{Symbol}()
    for kw in kwargs
        kw isa Expr && kw.head === :kw && length(kw.args) == 2 && kw.args[1] isa Symbol ||
            error("@simos sqlite.open internal parse error: expected keyword expr, got: $kw")
        key = kw.args[1]
        key in (:sync,) || error("@simos sqlite.open unknown option `$(key)`. Valid options: sync.")
        key in seen && error("@simos sqlite.open duplicate option `$(key)`.")
        push!(seen, key)
    end
    if isempty(kwargs)
        return quote
            $(_SimosAPI)._simos_sqlite_open_runtime!()
        end
    end
    return quote
        $(_SimosAPI)._simos_sqlite_open_runtime!(; $(kwargs...))
    end
end

function _simos_sqlite_current(mod, src)
    _ = mod
    _ = src
    return quote
        $(_SimosAPI)._simos_sqlite_current_runtime()
    end
end

function _simos_sqlite_execute(mod, src, args)
    _ = mod
    _ = src
    length(args) in (1, 2) || error("@simos sqlite.execute expects `(sql)` or `(sql, params)`.")
    sql_expr = args[1]
    if length(args) == 1
        return quote
            $(_SimosAPI)._simos_sqlite_execute_runtime($(sql_expr))
        end
    end
    params_expr = args[2]
    return quote
        $(_SimosAPI)._simos_sqlite_execute_runtime($(sql_expr), $(params_expr))
    end
end

function _simos_sqlite_refresh(mod, src)
    _ = mod
    _ = src
    return quote
        $(_SimosAPI)._simos_sqlite_refresh_runtime!()
    end
end

function _simos_sqlite_rebuild(mod, src)
    _ = mod
    _ = src
    return quote
        $(_SimosAPI)._simos_sqlite_rebuild_runtime!()
    end
end

function _simos_sqlite_close(mod, src)
    _ = mod
    _ = src
    return quote
        $(_SimosAPI)._simos_sqlite_close_runtime!()
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
                push!(sim.worksession.capture_policy.blob_vars, $(QuoteNode(v)))
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
                push!(sim.worksession.capture_policy.hash_vars, $(QuoteNode(v)))
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
                push!(sim.worksession.capture_policy.inline_vars, $(QuoteNode(v)))
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
                    sim.worksession.capture_policy.meta_buffer[$k] = $v
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
