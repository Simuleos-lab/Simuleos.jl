function _simos_sqlite_path(mod, src)
    return _simos_noargs_runtime_call(mod, src, :($(_SimosAPI)._simos_sqlite_path_runtime))
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
    return _simos_noargs_runtime_call(mod, src, :($(_SimosAPI)._simos_sqlite_current_runtime))
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
    return _simos_noargs_runtime_call(mod, src, :($(_SimosAPI)._simos_sqlite_refresh_runtime!))
end

function _simos_sqlite_rebuild(mod, src)
    return _simos_noargs_runtime_call(mod, src, :($(_SimosAPI)._simos_sqlite_rebuild_runtime!))
end

function _simos_sqlite_close(mod, src)
    return _simos_noargs_runtime_call(mod, src, :($(_SimosAPI)._simos_sqlite_close_runtime!))
end
