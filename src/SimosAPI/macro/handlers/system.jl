function _simos_init(mod, src, args)
    src_file = string(src.file)
    src_line = src.line

    opts = Dict{Symbol, Any}()
    for arg in args
        if arg isa Expr && arg.head == :(=) && length(arg.args) == 2 && arg.args[1] isa Symbol
            key = arg.args[1]
            val = arg.args[2]
            key in (:bootstrap, :sandbox, :reinit, :sandbox_cleanup, :project_basename_hint) ||
                error("@simos system.init unknown option `$(key)`. Valid options: bootstrap, sandbox, reinit, sandbox_cleanup, project_basename_hint.")
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
    project_basename_hint_expr = get(opts, :project_basename_hint, :(nothing))

    return quote
        $(_SimWS).engine_init_from_macro!($src_file, $src_line;
            bootstrap = $(bootstrap_expr),
            sandbox = $(sandbox_expr),
            reinit = $(reinit_expr),
            sandbox_cleanup = $(sandbox_cleanup_expr),
            project_basename_hint = $(project_basename_hint_expr),
        )
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
