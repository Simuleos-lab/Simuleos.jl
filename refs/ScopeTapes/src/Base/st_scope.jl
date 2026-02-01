# -- .- .-- -. . ---- .- .- . -.. - -- -.. --- -...
# MARK: st_rawscope
function _st_rawscope_ex()
    return quote

        local _loc = Base.@locals
        local _names = names(Main; imported = false)
        local _glob = Dict{Symbol, Any}()
        for f in _names
            isdefined(Main, f) || continue
            _glob[f] = getfield(Main, f)
        end
        local _scope = Dict{String, ScopeVariable}()

        for (k, v) in _glob
            k = string(k)
            _scope[k] = ScopeTapes.ScopeVariable(;
                key = k,
                src = :glob,
                val = v, 
                jl_type = typeof(v)
            )
        end

        for (k, v) in _loc
            k = string(k)
            _scope[k] = ScopeTapes.ScopeVariable(;
                key = k,
                src = :local,
                val = v, 
                jl_type = typeof(v)
            )
        end
        # save time and do not hash
        Scope(nothing, _scope)
    end |> esc
end

macro st_rawscope()
    return _st_rawscope_ex()
end

# MARK: st_scope
macro st_scope()
    quote
        ScopeTapes.@_post_init_check()
        ScopeTapes.st_run_hooks!(
            ScopeTapes.__ST, 
            ScopeTapes.@st_rawscope();
            docache = false
        )
    end |> esc
end

# MARK: st_show_scope
# TODO/ pretty print this (use StyledString) 
macro st_show_scope()
    quote 
        ScopeTapes.@_post_init_check()
        let
            sc = ScopeTapes.st_run_hooks!(
                ScopeTapes.__ST, 
                ScopeTapes.@st_rawscope();
                docache = false
            )
            println(sc)
        end
    end |> esc
end
