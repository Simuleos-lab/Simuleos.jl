function _simos_path_str(path)::String
    return join(string.(path), ".")
end

function _simos_parse_command_path(expr)
    if expr isa Symbol
        return Symbol[expr]
    end
    if expr isa Expr && expr.head === :. && length(expr.args) == 2
        left = _simos_parse_command_path(expr.args[1])
        right = expr.args[2]
        name = right isa QuoteNode ? right.value : right
        name isa Symbol || error("@simos command path segments must be symbols, got: $right")
        push!(left, name)
        return left
    end
    error("@simos expects a dotted command path like `session.init`, got: $expr")
end

function _simos_parse_do_payload(expr)
    if !(expr isa Expr && expr.head === :-> && length(expr.args) == 2)
        error("@simos do form expects `do ... end` without arguments.")
    end
    params = expr.args[1]
    if !(params isa Expr && params.head === :tuple && isempty(params.args))
        error("@simos do block must not declare arguments.")
    end
    return expr.args[2]
end

function _simos_split_call(call_expr)
    call_expr isa Expr && call_expr.head === :call || error("@simos expects call-style syntax: `@simos group.command(...)`")

    path = Tuple(_simos_parse_command_path(call_expr.args[1]))
    posargs = Any[]
    kwargs = Expr[]
    for arg in call_expr.args[2:end]
        if arg isa Expr && arg.head === :parameters
            for kw in arg.args
                kw isa Expr && kw.head === :kw && length(kw.args) == 2 && kw.args[1] isa Symbol ||
                    error("@simos keyword arguments must be `name=value`, got: $kw")
                push!(kwargs, kw)
            end
        elseif arg isa Expr && arg.head === :kw
            length(arg.args) == 2 && arg.args[1] isa Symbol ||
                error("@simos keyword arguments must be `name=value`, got: $arg")
            push!(kwargs, arg)
        else
            push!(posargs, arg)
        end
    end

    return path, posargs, kwargs
end

function _simos_parse_invocation(invocation_expr)
    payload_expr = nothing
    call_expr = invocation_expr
    if invocation_expr isa Expr && invocation_expr.head === :do
        length(invocation_expr.args) == 2 || error("@simos do syntax parse error.")
        call_expr = invocation_expr.args[1]
        payload_expr = _simos_parse_do_payload(invocation_expr.args[2])
    end

    path, posargs, kwargs = _simos_split_call(call_expr)
    return path, posargs, kwargs, payload_expr
end

function _simos_kw_to_assign(kw::Expr)
    kw.head === :kw && length(kw.args) == 2 && kw.args[1] isa Symbol ||
        error("@simos internal error: expected keyword expr, got: $kw")
    return Expr(:(=), kw.args[1], kw.args[2])
end

function _simos_kwargs_tuple_expr(kwargs::Vector{Expr})
    assigns = [_simos_kw_to_assign(kw) for kw in kwargs]
    return Expr(:tuple, assigns...)
end

"""
    _simos_extract_sgl_kwarg!(kwargs) -> Union{Bool, Nothing}

Pop `sgl=true/false` from kwargs if present. Returns `true`, `false`,
or `nothing` (no per-call override, defer to global flag).
"""
function _simos_extract_sgl_kwarg!(kwargs::Vector{Expr})
    idx = findfirst(kwargs) do kw
        kw.head === :kw && kw.args[1] === :sgl
    end
    isnothing(idx) && return nothing
    val = kwargs[idx].args[2]
    val isa Bool || error("@simos `sgl` option must be a literal `true` or `false`, got: $val")
    deleteat!(kwargs, idx)
    return val
end

function _simos_disallow_kwargs(path, kwargs)
    isempty(kwargs) || error("@simos $(_simos_path_str(path)) does not accept keyword arguments.")
end

function _simos_disallow_do(path, payload_expr)
    isnothing(payload_expr) || error("@simos $(_simos_path_str(path)) does not accept a `do` block.")
end

