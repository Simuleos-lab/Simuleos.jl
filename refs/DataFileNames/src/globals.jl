# -------------------------------------------------------------------
# _SEPS
const _SEPS = Dict{Symbol, String}()

function _filesep()
    dummy = joinpath("a", "a")
    reg = Regex("^a(?<sep>.*)a\$")
    sep = match(reg, dummy)["sep"]
    (length(sep) != 1) && error("Unsupported file separator")
    first(sep)
end

function _set_default_SEPS!()
    empty!(_SEPS)
    _SEPS[:EXT_SEP] = "."
    _SEPS[:PAIR_SEP] = "="
    _SEPS[:ELEMT_SEP] = "..."
    _SEPS[:PARAMS_LSEP] = "<<"
    _SEPS[:PARAMS_RSEP] = ">>"
    _SEPS[:SEP_SUBST] = "_"
    _SEPS[:FILE_SEP] = string(_filesep())
    _check__SEPS()
    return _SEPS
end

function _check__SEPS()
    isempty(_SEPS) && error("_SEPS is empty")
    !allunique(values(_SEPS)) && error("_SEPS are not unique. Current _SEPS ", _SEPS)
    return _SEPS
end

_hex_escaped_seps(ks = keys(_SEPS)) = Dict{Symbol, String}(k => hex_escape(_SEPS[k]) for k in ks)

# -------------------------------------------------------------------
# RESERVED SEPS
const _RESERVED_SEPS_KEYS = [:ELEMT_SEP, :PAIR_SEP, :PARAMS_LSEP, :PARAMS_RSEP, :FILE_SEP]
_reserved_seps() = [_SEPS[S] for S in _RESERVED_SEPS_KEYS]

# -------------------------------------------------------------------
# INPUT TYPES
const _INPUT_KEY_TYPES = [Symbol, String]
const _INPUT_VAL_TYPES = [Symbol, Bool, AbstractString, Integer, AbstractFloat]
const _INPUT_PAIRS_TYPES = [Pair, Dict, NamedTuple]

_iskeyT(k) = any(isa.([k], _INPUT_KEY_TYPES))
_isvalT(v) = any(isa.([v], _INPUT_VAL_TYPES))
_ispairT(p) = any(isa.([p], _INPUT_PAIRS_TYPES))

function _checker(v, isfun, name, types)
    !isfun(v) && 
        error("Invalid input ", name, " type, got ", v , "::",  typeof(v), 
            ", expected a type from [", join(types, ", "), "]"
        )
    return v
end

_check_keyT(k) = _checker(k, _iskeyT, "key", _INPUT_KEY_TYPES)
_check_valT(v) = _checker(v, _isvalT, "value", _INPUT_VAL_TYPES)
_check_pairT(p) = _checker(p, _ispairT, "key:value structure", _INPUT_PAIRS_TYPES)

# -------------------------------------------------------------------
# String validity
const INVALID_CHARS = Char[]

# function _check_str(str::AbstractString)

#     reserved_seps = _reserved_seps()
#     any(contains.(str, reserved_seps)) && 
        
#     any(contains.(str, INVALID_CHARS)) &&
#         error("Invalid char detected '$str'. INVALID_CHARS $INVALID_CHARS")
    
#     return str
# end


function _check_str(str::AbstractString, onerr::Function)

    reserved_seps = _reserved_seps()
    any(contains.(str, reserved_seps)) && return onerr(str, reserved_seps)
    any(contains.(str, INVALID_CHARS)) && return onerr(str, INVALID_CHARS)
    
    return str
end

invalid_str_error(str, pool) = error("Invalid sequence found in '$str'. Forbidden $pool")
_check_str(str::AbstractString) = _check_str(str, invalid_str_error)

# -------------------------------------------------------------------
const _OUTPUT_VAL_TYPES = [Int, Float64, Bool, String] # String must be the last, it is the fallback
