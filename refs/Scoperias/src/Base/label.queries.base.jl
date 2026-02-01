_sc_label_match(q::Regex, lb::String) = occursin(q, lb)
_sc_label_match(q::String, lb::String) = isequal(q, lb)

function _sc_scope_match_any_label(q, sc::Scope) 
    for scv in values(sc)
        sc_is_labelkey(scv.key) || continue
        _sc_label_match(q, scv.val) && return true
    end
    return false
end

function _sc_scope_match_any_label(qv::Vector, sc::Scope) 
    for q in qv
        _sc_scope_match_any_label(q, sc) && return true
    end
    return false
end


function _sc_scope_match_all(hook::SC_HOOK, sc::Scope)
    for q in hook.query
        _sc_scope_match_any_label(q, sc::Scope) || return false
    end
    return true
end