# ------------------------------------------------------------------
# base.jl — @simos base.hydrate / base.bind handlers
#
# General-purpose data tools that operate on any container with
# a `.variables` dict (SnapScopeV1, SnapSharedV1, etc.).
# Project is implicit (from active SimOs state).
# ------------------------------------------------------------------

# --- base.hydrate: resolve variables → NamedTuple ---

function _simos_base_hydrate(mod, src, args)
    _ = mod; _ = src
    length(args) >= 2 || error("@simos base.hydrate expects a container and at least one variable name (Symbol).")
    container_expr = args[1]
    var_syms = Symbol[]
    for arg in args[2:end]
        arg isa QuoteNode && (arg = arg.value)
        arg isa Symbol || error("@simos base.hydrate variable names must be Symbols, got: $arg")
        push!(var_syms, arg)
    end
    names_expr = Expr(:tuple, [QuoteNode(s) for s in var_syms]...)
    return quote
        $(_API)._simos_base_hydrate_runtime($(container_expr), $names_expr)
    end
end

function _simos_base_hydrate_runtime(container, names::Tuple{Vararg{Symbol}})
    proj = _Krn.sim_project()
    variables = _simos_resolve_variables(container)
    pairs = Pair{Symbol, Any}[]
    for name in names
        haskey(variables, name) || error("Variable `$(name)` not found in container.")
        push!(pairs, name => _Krn.scope_value(variables[name], proj))
    end
    return NamedTuple(pairs)
end

# --- base.bind: resolve variables + inject into caller scope ---

function _simos_base_bind(mod, src, args)
    _ = src
    length(args) >= 2 || error("@simos base.bind expects a container and at least one variable name.")
    container_expr = args[1]
    bind_args = args[2:end]
    # Use implicit project from active SimOs
    project_expr = :($(_Krn).sim_project())
    return _simos_bind_from_scope(mod, container_expr, project_expr, bind_args, "@simos base.bind")
end

# --- Shared: resolve .variables from any container ---

function _simos_resolve_variables(container)::Dict{Symbol, _Krn.ScopeVariable}
    hasproperty(container, :variables) ||
        error("Container $(typeof(container)) has no `.variables` field.")
    return container.variables
end
