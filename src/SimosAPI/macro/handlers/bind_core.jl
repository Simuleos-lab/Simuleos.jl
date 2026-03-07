# ------------------------------------------------------------------
# bind_core.jl — Shared bind codegen utilities
#
# Used by base.bind, shared.bind, and any future bind-like commands.
# ------------------------------------------------------------------

function _simos_parse_bind_spec(cmd::AbstractString, arg)
    if arg isa Symbol
        return (name = arg, type_expr = nothing)
    end
    if arg isa Expr && arg.head == :(::) && length(arg.args) == 2 && arg.args[1] isa Symbol
        return (name = arg.args[1], type_expr = arg.args[2])
    end
    error("$(cmd) expects variable names or typed bindings (`x` or `x::T`), got: $arg")
end

function _simos_bind_value_expr(value_sym::Symbol, type_expr)
    if isnothing(type_expr)
        return value_sym
    end
    return :((convert($(type_expr), $(value_sym))::$(type_expr)))
end

function _simos_bind_assign_expr(var::Symbol, value_expr, type_expr)
    _ = type_expr
    return :($(var) = $(value_expr))
end

function _simos_bind_from_scope(mod, scope_expr, project_expr, bind_args, cmd::AbstractString)
    isempty(bind_args) && error("$(cmd) expects at least one variable name.")
    bind_specs = [_simos_parse_bind_spec(cmd, arg) for arg in bind_args]

    scope_in = scope_expr
    project_in = project_expr
    caller_module = QuoteNode(mod)

    stmts = Expr[]
    for spec in bind_specs
        v = spec.name
        type_expr = spec.type_expr
        name = QuoteNode(v)
        level_sym = gensym(:bind_level)
        value_sym = gensym(:bind_value)
        bound_value_expr = _simos_bind_value_expr(value_sym, type_expr)
        local_assign_expr = _simos_bind_assign_expr(v, bound_value_expr, type_expr)
        push!(stmts, quote
            local $level_sym, $value_sym
            $level_sym, $value_sym = $(_Krn).scope_expand_runtime!($scope_in, $project_in, $name)
            if $level_sym === :global
                $(_Krn).scope_expand_setglobal!($caller_module, $name, $bound_value_expr)
            elseif $level_sym === :local || $level_sym === :shared
                $local_assign_expr
            else
                error("Unsupported scope level `$($level_sym)` for variable `$(string($name))`.")
            end
        end)
    end

    return Expr(:block, stmts...)
end
