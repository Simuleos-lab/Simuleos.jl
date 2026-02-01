function _gen_st_label_key(lb)
    return Symbol(string("st_label_", repr(hash(lb))))
end

function sc_check_for_local_label(sc::Scope)
    for scv in values(sc)
        sc_is_labelkey(scv.key) || continue
        scv.src == :local && return
    end
    error("No local label detected!")
end


function sc_is_labelkey(key::String)
    startswith(key, "st_label_")
end

function sc_haslabel(sc::Scope, reg::Regex)
    for (key, scv) in sc
        sc_is_labelkey(key) || continue
        occursin(reg, scv.val) && return true
    end
    return false
end


macro sc_label(lb)
    key = _gen_st_label_key(lb)
    quote
        $(key) = $(lb)::String
    end |> esc
end


macro _st_clear_mod_labels!(mod=Main)
    quote
        for f in names($(mod))
            isdefined($(mod), f) || continue
            Scoperias.sc_is_labelkey(string(f)) || continue
            $(mod).eval(:($(f) = ""))
        end
    end
end
