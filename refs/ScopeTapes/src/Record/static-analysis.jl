
function _find_assig(ex::Expr, gradpas, contexts = [])
    if (ex.head == Symbol("=")) 
        context = Dict{String, Any}()
        context["parents"] = gradpas
        context["assig"] = ex
        push!(contexts, context)
        return
    end
    parents = [gradpas; ex.head]
    for arg in ex.args
        _find_assig(arg, parents, contexts)
    end
end
_find_assig(_::Any, gradpas, contexts) = nothing

## --- .- -.. -- .-. . . .-- - -. . . .- .- .-.- .. .
# transforme this call `myfun(1, 2, a=3, b=4)` into
# ```
# myfun_arg1 = 1;
# myfun_arg2 = 2;
# myfun_kwarg_a = 3;
# myfun_kwarg_b = 4;
# myfun(myfun_arg1, myfun_arg2, a=myfun_kwarg_a, b=myfun_kwarg_b)
# ```

macro expand_call(call_expr)
    if call_expr.head != :call
        error("@expand_call must be used with a function call")
    end

    func_name = call_expr.args[1]
    args = call_expr.args[2:end]

    pre_stmts = Expr(:block)
    new_args = Expr(:call, func_name)
    pos_index = 1

    for arg in args
        if arg isa Expr && arg.head == :kw
            # Keyword argument: a = 3
            key = arg.args[1]
            val = arg.args[2]
            varname = Symbol("$(func_name)_kwarg_", key)
            push!(pre_stmts.args, :( $varname = $val ))
            push!(new_args.args, Expr(:kw, key, varname))
        else
            # Positional argument
            varname = Symbol("$(func_name)_arg", pos_index)
            push!(pre_stmts.args, :( $varname = $arg ))
            push!(new_args.args, varname)
            pos_index += 1
        end
    end

    # Append the modified function call
    push!(pre_stmts.args, new_args)

    return esc(pre_stmts)
end

## --- .- -.. -- .-. . . .-- - -. . . .- .- .-.- .. .
myfun(x1, x2; a, b) = println((;x1, x2, a, b))

## --- .- -.. -- .-. . . .-- - -. . . .- .- .-.- .. .
let
    @expand_call myfun(1, 2, a=3, b=4)
    @show myfun_arg1
    @show myfun_arg2

end
