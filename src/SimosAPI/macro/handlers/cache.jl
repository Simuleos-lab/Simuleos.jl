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
