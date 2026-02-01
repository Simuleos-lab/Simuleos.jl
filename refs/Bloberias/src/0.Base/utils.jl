uuid_one() = UInt128(1)
# uuid_int() = uuid4().value
function uuid_int()
    _1 = uuid_one()
    while true
        _u = uuid4().value
        _u != _1 && return _u
    end
end
uuid_str() = repr(uuid_int())

_noop(x...) = nothing

# _ismatch(pt, str)
_ismatch(pt::Function, y) = pt(y) === true
_ismatch(pt::AbstractChar, y::AbstractString) = isequal(string(pt), y)
_ismatch(pt::AbstractString, y::AbstractString) = startswith(y, pt)
_ismatch(pt::Regex, y::String) = !isnothing(match(pt, string(y)))
_ismatch(pt) = Base.Fix1(_ismatch, pt)
_ismatch(::Nothing, y) = true  # pass
_ismatch(pt, y) = isequal(pt, y)

function _mkpath(path)
    dir = isdir(path) ? path : dirname(path)
    mkpath(dir)
end

function _quoted_join(col, sep)
    strs = String[]
    for el in col
        push!(strs, string("\"", el, "\""))
    end
    return join(strs, sep)
end


function _canonical_bytes(bytes)
    bytes < 1024 && return (bytes, "bytes")
    bytes /= 1024
    bytes < 1024 && return (bytes, "kilobytes")
    bytes /= 1024
    bytes < 1024 && return (bytes, "Megabytes")
    bytes /= 1024
    bytes < 1024 && return (bytes, "Gigabytes")
    bytes /= 1024
    return (bytes, "Tb")
end

function _pretty_print_pairs(io::IO, k, v)
    print(io, string(k), ": ")
    printstyled(io, string(v); color = :blue)
end

# function _field_hash(obj, h = 0)
#     h = hash(h)
#     for f in fieldnames(typeof(obj))
#         v = getfield(obj, f)
#         _valid_type = false
#         _valid_type |= isa(v, String)
#         _valid_type |= isa(v, Symbol)
#         _valid_type |= isa(v, Integer)
#         _valid_type || continue
#         h = hash(v, h)
#     end
#     return h
# end

# order is not important
function _combhash(comb...; h0 = zero(UInt))
    h = h0
    for x in comb
        h ⊻= hash(x)
    end
    return h
end

function _recursive_filesize(root0)
    fsize = 0.0;
    for (root, _, files) in walkdir(root0)
        for file in files
            fsize += filesize(joinpath(root, file)) # path to files
        end
    end
    return fsize
end

function _getindex(os::OrderedSet, i0)
    for (i, v) in enumerate(os)
        i == i0 && return v
    end
    throw(BoundsError(os, i0))
end

_constant(v) = (x...) -> v 

function _bb_show_file_sortby(ph)
    name = basename(ph)
    name == "meta.jls" && return "."
    name == "buuids.jls" && return ".."
    return name
end

function _show_disk_files(filter::Function, io::IO, root; 
            fc = :normal, 
            bc = :normal,
            sc = :blue
        )
    
    names = isdir(root) ? readdir(root; join = false) : []
    isempty(names) && return
    sort!(names; by = _bb_show_file_sortby)
    _npad = maximum(length.(names); init = 0)
    print(io, "\n\nDisk files: \n")
    for name in names
        path = joinpath(root, name)

        filter(path) === true || continue

        val, unit = _canonical_bytes(filesize(path))
        print(io, "   ")
        _file_str = rpad(string("\"", name, "\" "), _npad + 4, ' ')
        printstyled(io, _file_str; color = fc)
        print(io, " ")
        _size_str = string(round(val; digits = 3), " ", unit)
        printstyled(io, _size_str; color = sc)
        print(io, "\n")
    end
    print(io, "\ndisk usage: ")
    val, unit = _canonical_bytes(_recursive_filesize(root))
    _size_str = string(round(val; digits = 3), " ", unit)
    printstyled(io, _size_str; color = sc)
end

## --.--. - .-. .- .--.-.- .- .---- ... . .-.-.-.- 
# util callers
_functionalize(f::Function) = f
_functionalize(v::Any) = (x...) -> v

function _trycall(call, onerr)
    onerr = _functionalize(onerr)
    call = _functionalize(call)
    try; return call()
        catch err; return onerr(err)
    end
end
struct _IGNORE end
_trycall(call, ::Type{_IGNORE}) = call()

function _conditionalcall(ontrue, cond::Bool, onfalse)
    ontrue = _functionalize(ontrue)
    onfalse = _functionalize(onfalse)
    return cond ? ontrue() : onfalse()
end
_conditionalcall(call, ::Type{_IGNORE}, onfail) = call()
