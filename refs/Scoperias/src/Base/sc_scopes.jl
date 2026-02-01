# -- .- .-- -. . ---- .- .- . -.. - -- -.. --- -...
# MARK: st_rawscope
function _sc_rawscope_ex()
    return quote
        let
            local _loc = Base.@locals
            local _names = names(Main; imported = false)
            local _glob = Dict{Symbol, Any}()
            for f in _names
                isdefined(Main, f) || continue
                _glob[f] = getfield(Main, f)
            end
            local _scope = Dict{String, SimuleosScopeVariable}()

            for (k, v) in _glob
                k = string(k)
                _scope[k] = Scoperias.SimuleosScopeVariable(;
                    key = k,
                    val = v, 
                    src = :global,
                )
            end

            for (k, v) in _loc
                k = string(k)
                _scope[k] = Scoperias.SimuleosScopeVariable(;
                    key = k,
                    src = :local,
                    val = v, 
                )
            end
            # save time and do not hash
            Scope(_scope)
        end
    end |> esc
end

macro sc_rawscope()
    return _sc_rawscope_ex()
end

# MARK: sc_scope
macro sc_scope(lb = "")
    quote
        let
            # create label
            isempty($(lb)) || Scoperias.@sc_label $(lb)
            local rsc = Scoperias.@sc_rawscope()
            Scoperias.sc_check_for_local_label(rsc)
            Scoperias.sc_run_sel_hooks(rsc)
        end
    end |> esc
end

# MARK: st_show_scope
# TODO/ pretty print this (use StyledString) 
macro sc_show_scope(lb="")
    quote 
        let
            sc = sc_scope($(lb))
            println(sc)
        end
    end |> esc
end
