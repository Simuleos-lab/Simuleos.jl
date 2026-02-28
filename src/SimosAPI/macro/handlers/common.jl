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

function _simos_noargs_runtime_call(mod, src, runtime_expr)
    _ = mod
    _ = src
    return quote
        $(runtime_expr)()
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
