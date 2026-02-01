function _check_symbols(mod, symbols)
    foreach(symbols) do symbol 
        isdefined(mod, symbol) && error(
            "Project generation fails, ", symbol, " already exist. ", 
            "If this is intended place the generator function at the to of the containing module."
        )
    end
end

# ---------------------------------------------------------------------
function gen_top_proj(mod::Module, dir = nothing)

    # check proj
    _is_proj(mod) && error("Module ($(mod)) is already a ProjAssitant project.")

    # dir
    if isnothing(dir)
        modpath = pathof(mod)
        isnothing(modpath) && error("Module `", mod , "` must have a path to be a top project")
        dir = dirname(dirname(modpath))
    end
        
    # Check symbols
    _check_symbols(mod, [:_PROJ_ASSIST_CONF])
    
    # eval
    @eval mod begin
        const _PROJ_ASSIST_CONF = Dict{Symbol, Any}()
        _PROJ_ASSIST_CONF[:ROOT_DIR] = $(dir)
        _PROJ_ASSIST_CONF[:PARENT_PROJ] = $(mod)
        _PROJ_ASSIST_CONF[:TOP_PROJ] = $(mod)
        nothing
    end
end

# ---------------------------------------------------------------------
macro gen_top_proj()
    quote $(gen_top_proj)(@__MODULE__) end
end

macro gen_top_proj(dirkw)
    # get dir
    k, dir = dirkw.args
    validarg = Meta.isexpr(dirkw, :(=)) && (k == :dir)
    !validarg &&
        error("An expression `dir=path::AbstractString` is expected")
    
    quote $(gen_top_proj)(@__MODULE__, $(esc(dir))) end
end
