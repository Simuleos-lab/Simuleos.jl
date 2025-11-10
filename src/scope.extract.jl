# -- .- .-- -. . ---- .- .- . -.. - -- -.. --- -...
# MARK: st_rawscope
function _rawscope_ex()
    return quote
        let
            local _loc = Base.@locals
            local _names = names(Main; imported = false)
            local _glob = Dict{Symbol, Any}()
            for f in _names
                isdefined(Main, f) || continue
                _glob[f] = getfield(Main, f)
            end
            local _scope = Dict{String, Any}()

            # Addd scope
            for (k, v) in _glob
                k = string(k)
                _scope[k] = Dict{String, Any}(
                    "key" => k,
                    "val" => v, 
                    "src" => :global,
                )
            end

            for (k, v) in _loc
                k = string(k)
                _scope[k] = Dict{String, Any}(
                    "key" => k,
                    "val" => v, 
                    "src" => :local,
                )
            end

            # Add metadata
            # TODO/TAI: Maybe add this just before storing
            _scope["_Simuleos.meta"] = Dict{String, Any}(
                # TODO: Use universal timezone
                "bird.time" => time(),
                # TODO/TAI: Add filepath
                # TODO/TAI: Add filehash
                # TODO/TAI: Add commit report
            )

            # Important, do not add an explicit return
            _scope
        end
    end |> esc
end

macro sim_rawscope()
    return _rawscope_ex()
end

# MARK: sc_scope
macro sim_scope(lb = "")
    quote
        let
            # create label
            # isempty($(lb)) || Scoperias.@sim_label $(lb)
            # local rsc = Scoperias.@sim_rawscope()
            # Scoperias.sc_check_for_local_label(rsc)
            # Scoperias.sc_run_sel_hooks(rsc)
        end
    end |> esc
end

# MARK: st_show_scope
# TODO/ pretty print this (use StyledString) 
macro sim_show_scope(lb="")
    quote 
        let
            sc = sc_scope($(lb))
            println(sc)
        end
    end |> esc
end
