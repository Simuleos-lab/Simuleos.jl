function _gen_st_label_key(lb)
    return Symbol(string("st_label_", repr(hash(lb))))
end


function st_is_labelkey(key::String)
    startswith(key, "st_label_")
end

function st_haslabel(sc::Scope, reg::Regex)
    for (key, scv) in sc
        st_is_labelkey(key) || continue
        occursin(reg, scv.val) && return true
    end
    return false
end


macro st_label(lb)
    key = _gen_st_label_key(lb)
    quote
        ScopeTapes.@_post_init_check()
        $(key) = $(lb)::String
    end |> esc
end


macro _st_clear_mod_labels!(mod=Main)
    quote
        for f in names($(mod))
            isdefined($(mod), f) || continue
            ScopeTapes.st_is_labelkey(string(f)) || continue
            $(mod).eval(:($(f) = ""))
        end
    end
end
