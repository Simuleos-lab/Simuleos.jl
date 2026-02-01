## ----------------------------------------------------------------------------
# _GLOBAL_CONF
const _GLOBAL_CONF = Dict()

function _init_globals()
    empty!(_GLOBAL_CONF)
    _GLOBAL_CONF[:CACHE_DIR] = pwd()
    _GLOBAL_CONF[:VERBOSE] = false
    _GLOBAL_CONF[:PRINT_FUN] = Base.println
    _GLOBAL_CONF[:LOAD_FUN] = _load
    _GLOBAL_CONF[:SAVE_FUN] = _save
    _GLOBAL_CONF[:ADD_TAG] = false
    _GLOBAL_CONF[:MK_DIR] = true
end

## ----------------------------------------------------------------------------
_toupper(s::Symbol) = Symbol(uppercase(string(s)))
global_conf() = _GLOBAL_CONF
global_conf(id::Symbol) = getindex(_GLOBAL_CONF, _toupper(id))
global_conf(id::Symbol, val) = (setindex!(_GLOBAL_CONF, val, _toupper(id)); val)