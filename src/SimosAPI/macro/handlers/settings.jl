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
    return _simos_noargs_runtime_call(mod, src, :($(_SimosAPI)._simos_settings_layers_runtime))
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
    return _simos_noargs_runtime_call(mod, src, :($(_SimosAPI)._simos_settings_source_list_runtime))
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
