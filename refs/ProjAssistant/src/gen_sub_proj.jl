function _find_parent_proj(currmod)
    parent = parentmodule(currmod)
    (currmod == parent) && return parent
    _is_proj(parent) && return parent
    _find_parent_proj(parent)
end

function gen_sub_proj(currmod::Module, parentmod = _find_parent_proj(currmod))

    # ---------------------------------------------------------------------
    # Check parenthood
    _is_proj(currmod) && error("Module ($(currmod)) is already a ProjAssitant project.")
    !_is_proj(parentmod) && error("Parent module ($(parentmod)) is not a ProjAssitant project.")

    # ---------------------------------------------------------------------
    # Check symbols
    _check_symbols(mod, [:_PROJ_ASSIST_CONF])

    # ---------------------------------------------------------------------
    # top funs
    @eval currmod begin
        const _PROJ_ASSIST_CONF = Dict{Symbol, Any}()
        _PROJ_ASSIST_CONF[:PARENT_PROJ] = $(parentmod)
        _PROJ_ASSIST_CONF[:TOP_PROJ] = $(topproj)($(parentmod))
        nothing
    end
end

# ---------------------------------------------------------------------
macro gen_sub_proj()
    quote $(gen_sub_proj)(@__MODULE__) end
end

macro gen_sub_proj(dirkw)
    # get dir
    k, parent = dirkw.args
    validarg = Meta.isexpr(dirkw, :(=)) 
    validarg &= (k == :parent) && (parent isa Symbol)
    !validarg && error("An expression `parent=mod::Module` is expected, got ", dirkw)
    
    quote $(gen_sub_proj)(@__MODULE__, $(esc(parent))) end
end

