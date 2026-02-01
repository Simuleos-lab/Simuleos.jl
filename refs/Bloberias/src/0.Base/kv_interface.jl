## ------------------------------------------------------------------
# Each data point must have an associated key [String].
# For a valueless pair we use an empty holder...

## ------------------------------------------------------------------
const _KV_NOVAL = :__NOVAL

## ------------------------------------------------------------------
# kw vec interface
_kv_key(obj::Pair) = string(first(obj))
_kv_key(obj::String) = obj
_kv_key(obj) = string(obj)

_kv_val(obj::Pair) = last(obj)
_kv_val(::String) = _KV_NOVAL
_kv_val(obj) = obj # for general objects

_kv_dict(vals::Vector) = Dict(_kv_key(v) => _kv_val(v) for v in vals)
# _kv_oddict(vals::Vector) = OrderedDict(_kv_key(v) => _kv_val(v) for v in vals)

function _kv_vec(vals...; kwargs...)
    vec = Any[]
    for val in vals
        push!(vec, val)
    end
    for val in kwargs
        push!(vec, _kv_key(val) => _kv_val(val))
    end
    return vec
end

_kv_vec(vals::AbstractDict) = Any[_kv_key(obj) => _kv_val(obj) for obj in vals]

function _kv_compact_vec!(kval::Vector)
    for (i, kv) in enumerate(kval)
        _kv_val(kv) == _KV_NOVAL || continue
        kval[i] = _kv_key(kv)
    end
    kval
end

## ------------------------------------------------------------------
function _kv_print_val(io::IO, vals)
    print(io, "[")
    for p in vals
        k, val = _kv_key(p), _kv_val(p)
        if val === :__NOVAL; print(io, repr(k), ", ")
            else; print(io, repr(k), " => ", repr(val), ", ")
        end
    end
    print(io, "]")
end

function _lim_str(s, lim)
    length(s) < lim && return s
    return string(first(s, lim), "...")
end

function _kv_print_type(io::IO, vals; 
        _typeof = typeof, 
        kc = :green,
        vc = :blue,
        bc = :normal,
        clim = 40
    )
    N = length(vals)
    _k_strs = Vector{String}(undef, N)
    _v_strs = Vector{String}(undef, N)
    for (i, p) in enumerate(vals)
        k, val = _kv_key(p), _kv_val(p)
        _k_strs[i] = _lim_str(repr(k), clim)
        _v_strs[i] = _lim_str(string(_typeof(val)), clim)
    end
    printstyled(io, "["; color = bc)
    for (i, (k, v)) in enumerate(zip(_k_strs, _v_strs))
        printstyled(io, k; color = kc)
        printstyled(io, "::"; color = bc)
        printstyled(io, v; color = vc)
        i != N && printstyled(io, ", "; color = bc)
    end
    printstyled(io, "]"; color = bc)
end
