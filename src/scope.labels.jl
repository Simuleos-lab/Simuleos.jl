# MARK: Base
function _gen_label_key(lb)
    return Symbol(string("_sim_label_", repr(hash(lb))))
end

function sim_is_labelkey(key::String)
    startswith(key, "_sim_label_")
end

macro sim_label(lb)
    key = _gen_label_key(lb)
    quote
        $(key) = $(lb)::String
    end |> esc
end


macro _clear_mod_labels!(mod=Main)
    quote
        for f in names($(mod))
            isdefined($(mod), f) || continue
            SimuleosCore.simuleos_is_labelkey(string(f)) || continue
            $(mod).eval(:($(f) = ""))
        end
    end
end



# MARK: Utils
# function sc_check_for_local_label(sc::Scope)
#     for scv in values(sc)
#         simuleos_is_labelkey(scv.key) || continue
#         scv.src == :local && return
#     end
#     error("No local label detected!")
# end

# function sc_haslabel(sc::Scope, reg::Regex)
#     for (key, scv) in sc
#         simuleos_is_labelkey(key) || continue
#         occursin(reg, scv.val) && return true
#     end
#     return false
# end
