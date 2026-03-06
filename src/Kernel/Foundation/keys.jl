# ============================================================
# keys.jl — Canonical key conversion helpers
# ============================================================

"""
    _to_string_key(k) -> String

Convert a dictionary key to canonical `String` form.
Accepted key types: `AbstractString` and `Symbol`.
"""
function _to_string_key(k)::String
    if k isa String
        return k
    elseif k isa AbstractString
        return String(k)
    elseif k isa Symbol
        return String(k)
    end
    error("Key type mismatch: expected String/Symbol key, got $(typeof(k)).")
end

"""
    _to_symbol_key(k) -> Symbol

Convert a dictionary key to canonical `Symbol` form.
Accepted key types: `AbstractString` and `Symbol`.
"""
function _to_symbol_key(k)::Symbol
    if k isa Symbol
        return k
    elseif k isa AbstractString
        return Symbol(String(k))
    end
    error("Key type mismatch: expected String/Symbol key, got $(typeof(k)).")
end
