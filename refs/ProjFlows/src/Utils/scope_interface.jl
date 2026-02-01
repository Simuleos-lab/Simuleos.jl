# -- .- .-- -. . ---- .- .- . -.. - -- -.. --- -...
# Alternative names: localctx, peekctx,
function _scope_ex(prefix="")
    return quote
        local _mod = @__MODULE__
        local _glob = Dict(f => getfield(_mod, f) for f in names(_mod))
        local _loc = Base.@locals
        local _scope = Dict{String, Any}()
        for (k, v) in _glob
            _scope[string($(prefix), k)] = v
        end
        for (k, v) in _loc
            _scope[string($(prefix), k)] = v
        end
        _scope
    end
end

macro scope(prefix="")
    return _scope_ex(prefix)
end