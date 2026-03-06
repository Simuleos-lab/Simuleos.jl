function _simos_session_init(mod, src, args)
    src_file = string(src.file)
    src_line = src.line
    return quote
        $(_WS).session_init_from_macro!(Any[$(args...)], $src_file, $src_line)
    end
end

function _simos_commit(mod, src, args)
    label_expr = isempty(args) ? "" : args[1]
    return quote
        $(_WS).session_commit(string($label_expr))
    end
end

function _simos_batch_commit(mod, src, args, kwargs::Vector{Expr}=Expr[])
    label_expr = isempty(args) ? "" : args[1]
    if isempty(kwargs)
        return quote
            $(_WS).session_batch_commit(string($label_expr))
        end
    end
    return quote
        $(_WS).session_batch_commit(string($label_expr); $(kwargs...))
    end
end

function _simos_finalize(mod, src, args)
    label_expr = isempty(args) ? "" : args[1]
    return quote
        $(_WS).session_finalize(string($label_expr))
    end
end
