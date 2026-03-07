# ------------------------------------------------------------------
# session.jl — @simos session.* handlers (session lifecycle)
#
# session.init — start a session
# session.close — finalize and flush
# ------------------------------------------------------------------

function _simos_session_init(mod, src, args)
    src_file = string(src.file)
    src_line = src.line
    return quote
        $(_WS).session_init_from_macro!(Any[$(args...)], $src_file, $src_line)
    end
end

function _simos_session_close(mod, src, args)
    label_expr = isempty(args) ? "" : args[1]
    return quote
        $(_WS).session_finalize(string($label_expr))
    end
end
