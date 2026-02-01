# -------------------------------------------------------------------
# parse_arg
"""
This is part of the public interface.
Implement a new method for parsing a new type.
`parse_arg` must return one of the following types 
[`Symbol`, `Int`, `Float64`, `String`, `Bool`, `NamedTuple`, `Dict`]
or other type that already has an implemented `parse_arg` method.
For the case in `NamedTuple` and `Dict`, the keys and values must be 
one of the first other types.
    
# Example:
```julia
struct Foo
    x::Int
    y::String
end
parse_arg(f::Foo) = (;f.x, f.y)

foo = Foo(1, "A")
fname = dfname("my_foo", foo, ".ext")
# "my_foo [x=1 y=A].ext"
```
"""
parse_arg
parse_arg(s::Symbol) = s
parse_arg(n::Integer) = n
parse_arg(f::AbstractFloat) = f
parse_arg(s::AbstractString) = string(s)
parse_arg(b::Bool) = b
parse_arg(p::Pair) = p
parse_arg(pt::NamedTuple) = pt
parse_arg(pt::Iterators.Pairs) = parse_arg(Dict(pt...))
parse_arg(pt::Dict) = pt
parse_arg(v::VersionNumber) = string(v)
parse_arg(v::Any) = error("parse_arg(v::", typeof(v), ") not implemented. Type `?parse_arg` for help.")
# A tupple will be hashed
function parse_arg(pt::Tuple)
    h = hash(0)
    for el in pt
        h = hash(el, h)
    end
    return (;hash = repr(h))
end

# -------------------------------------------------------------------
# _argstr
_argstr(s::Symbol) = _check_str(string(s))
_argstr(n::Integer) = _check_str(repr(n))
_argstr(f::AbstractFloat) = _check_str(@sprintf("%0.2e", f))
_argstr(s::AbstractString) = _check_str(string(s))
_argstr(b::Bool) = _check_str(string(b))

## ------------------------------------------------------------------
# Will extract the first Vector{<:AbstractString} args and makes 
# them a path and returns the rest
function _extract_dir(args...)
    isempty(args) && return ("", args)
    path = ""
    for (i, arg) in enumerate(args)
        !(arg isa Vector{<:AbstractString}) && return (path, args[i:end])
        for dir in arg
            path = joinpath(path, dir)
        end
    end
    return (path, tuple())
end

## ------------------------------------------------------------------
# assumes _extract_dir was already called
# extract all first _isvalT ignoring the last arg
function _extract_head(args...)
    head_args = []
    isempty(args) && return (head_args, args)
    lasti = lastindex(args)
    for (i, arg) in enumerate(args)
        parg = parse_arg(arg)
        if ((i != lasti) && _isvalT(parg)); push!(head_args, parg)
            else; return (head_args, args[i:end])
        end
    end
    return (head_args, tuple(args[lasti]))
end

# -------------------------------------------------------------------
# assumes _extract_head was already called
# extract all first _ispairT
function _extract_params(args...)
    params_args = []
    isempty(args) && return (params_args, args)
    for (i, arg) in enumerate(args)
        parg = parse_arg(arg)
        if _ispairT(parg); push!(params_args, parg)
            else; return (params_args, args[i:end])
        end
    end
    return (params_args, tuple())
end

# -------------------------------------------------------------------
function _extract_ext(args...)
    len = length(args)
    for arg in args
        parg = parse_arg(arg)
        _isT = _isvalT(parg)
        # valid ext arg
        (_isT && len == 1) && return parg 
        # several args
        _isT && error(
            "After the first key:value argument no single value is allowed (except the extension at the end). ", 
            "Type protocole_desc() for info!"
        )
        # here such arg should also fails _ispairT
        error("parse_arg(a::$(typeof(arg))) returns an invalid type. Use `?parse_arg` for help.")
    end
    return "" # default ext
end

# -------------------------------------------------------------------
# dfname
function _dfname(args...)
    _check__SEPS()

    # --------------------------------------------------------
    # extract args
    head_args, args = _extract_head(args...)
    params_args, args = _extract_params(args...)
    
    # --------------------------------------------------------
    # deal with ext
    extarg = _extract_ext(args...)
    sextarg = _argstr(extarg)
    if startswith(sextarg, _SEPS[:EXT_SEP]) || isempty(sextarg)
        ext = sextarg
    elseif length(params_args) > 0
        ext = string(_SEPS[:EXT_SEP], sextarg)
    else
        # is not an extension
        ext = _argstr("")
        push!(head_args, sextarg)
    end

    # --------------------------------------------------------
    # join params to check for collisions
    params_dict = Dict()
    for param_arg in params_args
        param_arg = (param_arg isa Pair) ? [param_arg] : pairs(param_arg)
        for (k, v) in param_arg
            ck = _check_keyT(k)
            cv = _check_valT(v)
            strk = _argstr(ck)
            strv = _argstr(cv)

            haskey(params_dict, strk) && 
                error("You have passed two keys that lead to the same string '", strk, "'. Collisions are not allowed")
            params_dict[strk] = strv
        end
    end

    # --------------------------------------------------------
    # build name
    head_strs = [_argstr(arg) for arg in head_args]
    params_scol = sort!(collect(params_dict); by = first)
    params_strs = [string(k, _SEPS[:PAIR_SEP], v) for (k, v) in params_scol]
    if !isempty(params_strs)
        param_str = string(
            _SEPS[:PARAMS_LSEP], 
            join(params_strs, _SEPS[:ELEMT_SEP]), 
            _SEPS[:PARAMS_RSEP]
        )
        push!(head_strs, param_str)
    end
    filter!(!isempty, head_strs)
    fname = string(join(head_strs, _SEPS[:ELEMT_SEP]), ext)
    
    # --------------------------------------------------------
    # happyness
    return fname
end

_dfname() = ""
_dfname(fname::String) = isvalid_dfname(fname) ? fname : _dfname("", fname)

function dfname(args...) 
    dir, args = _extract_dir(args...)
    fname = _dfname(args...)
    isempty(fname) ? dir : joinpath(dir, fname)
end
