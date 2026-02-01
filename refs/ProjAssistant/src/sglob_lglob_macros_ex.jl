## ------------------------------------------------------
_parse_gids(syms::Vector{Symbol}, s::Symbol) = push!(syms, s)
_parse_gids(syms::Vector{Symbol}, qn::QuoteNode) = _parse_gids(syms, qn.value)
function _parse_gids(syms::Vector{Symbol}, ex::Expr)
    if Meta.isexpr(ex, [:(.)])
        _parse_gids(syms, ex.args[1])
        _parse_gids(syms, ex.args[2])
    else
        _gids_invalid_syntax_err(ex)
    end
end
_gids_invalid_syntax_err(ex) = error("Invalid syntax, use 'gid.gid...' or 'gid=gid.gid...'. At ex: ", ex)
_parse_gids(::Vector{Symbol}, obj) = _gids_invalid_syntax_err(obj)

## ------------------------------------------------------
function _lglob_macro_ex(Proj, exs...)
    # collect dat
    index = Dict{Symbol, Vector{Symbol}}()
    for ex in exs
        gids = Symbol[]
        if (ex isa Symbol) || Meta.isexpr(ex, [:(.)])
            # @lglob ider
            # @lglob ider1.ider2
            _parse_gids(gids, ex)
            var = last(gids)
        elseif Meta.isexpr(ex, [:(=)])
            # @lglob ider2=...
            lhand = ex.args[1]
            rhand = ex.args[2]

            !(lhand isa Symbol) && _gids_invalid_syntax_err(ex)
            var = lhand 
            _parse_gids(gids, rhand)
        else
            _gids_invalid_syntax_err(ex)
        end
        
        haskey(index, var) && error("Name collision are not allowed. Name: '", var, 
            "'. Exs: '", join(string.(index[var]), "."), "' and '",  string(ex), "'."
        )
        index[var] = gids
    end

    # expression
    ex = quote 
        !($(esc(Proj)) isa Module) && error($(Proj), "must be a Module identifier")
    end
    for (ider, gids) in index
        ex = quote
            $(ex)
            $(esc(ider)) = $(lglob)($(esc(Proj)), $(gids)...)
        end
    end
    ex = quote 
        $(ex)
        nothing
    end

    return ex
end

## ------------------------------------------------------
_sglob_invalid_syntax_err(ex) = error("Invalid syntax, use 'Proj gid' or 'Proj gid.gid...=Expr'. At ex: ", ex)

function _sglob_macro_ex(Proj, exs...)
    
    # collect dat
    index = Dict{Vector{Symbol}, Any}()
    for ex in exs
        gids = Symbol[]
        if (ex isa Symbol) || Meta.isexpr(ex, [:(.)])
            # @sglob ider2
            _parse_gids(gids, ex)
            index[gids] = last(gids)
        elseif Meta.isexpr(ex, [:(=)])
            # @sglob ider2=Expr
            lhand = ex.args[1]
            rhand = ex.args[2]
            
            _parse_gids(gids, lhand)
            index[gids] = rhand
        else
            _sglob_invalid_syntax_err(ex)
        end
    end

    # expression
    ex = quote 
        !($(esc(Proj)) isa Module) && error($(Proj), "must be a Module identifier")
    end
    for (gids, datexpr) in index
        ex = quote
            $(ex)
            $(sglob)($(esc(Proj)), $(esc(datexpr)), $(gids)...)
        end
    end
    ex = quote 
        $(ex)
        nothing
    end

    return ex
end