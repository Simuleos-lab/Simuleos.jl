function _simos_init(mod, src, args)
    src_file = string(src.file)
    src_line = src.line

    _ = mod
    opts = Dict{Symbol, Any}()
    for arg in args
        if arg isa Expr && arg.head == :(=) && length(arg.args) == 2 && arg.args[1] isa Symbol
            key = arg.args[1]
            val = arg.args[2]
            haskey(opts, key) && error("@simos system.init duplicate option `$(key)`.")
            key == :bootstrap &&
                error("@simos system.init `bootstrap` was removed. Pass runtime settings as direct keyword args.")
            opts[key] = val
        else
            error("@simos system.init is engine-only and does not accept session labels. Use `@simos session.init(...)`.")
        end
    end

    kwargs_exprs = [Expr(:kw, k, v) for (k, v) in opts]

    return quote
        $(_SimWS).engine_init_from_macro!($src_file, $src_line;
            $(kwargs_exprs...),
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
