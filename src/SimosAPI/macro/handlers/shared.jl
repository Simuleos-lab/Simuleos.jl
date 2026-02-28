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
