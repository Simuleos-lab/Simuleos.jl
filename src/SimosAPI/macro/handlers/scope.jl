function _simos_capture(mod, src, args)
    label_expr = isempty(args) ? "" : args[1]
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

            $(_SimWS).scope_capture(
                string($label_expr),
                _locals,
                _globals,
                $src_file,
                $src_line,
            )
        end
    end
end

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
        level_sym = gensym(:scope_expand_level)
        value_sym = gensym(:scope_expand_value)
        bound_value_expr = _simos_bind_value_expr(value_sym, type_expr)
        local_assign_expr = _simos_bind_assign_expr(v, bound_value_expr, type_expr)
        push!(stmts, quote
            local $level_sym, $value_sym
            $level_sym, $value_sym = $(_SimKrn).scope_expand_runtime!($scope_in, $project_in, $name)
            if $level_sym === :global
                $(_SimKrn).scope_expand_setglobal!($caller_module, $name, $bound_value_expr)
            elseif $level_sym === :local || $level_sym === :shared
                $local_assign_expr
            else
                error("Unsupported scope level `$($level_sym)` for variable `$(string($name))`.")
            end
        end)
    end

    return Expr(:block, stmts...)
end

function _simos_expand(mod, src, args)
    _ = src
    length(args) >= 3 || error("@simos scope.bind expects scope, project, and at least one variable name.")
    scope_expr = args[1]
    project_expr = args[2]
    bind_args = args[3:end]
    return _simos_bind_from_scope(mod, scope_expr, project_expr, bind_args, "@simos scope.bind")
end
