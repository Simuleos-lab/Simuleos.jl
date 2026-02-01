
## --.-..-..-- -- - - - . . .. .- - .- .-. .- . . .. -. - ..
# Basic read/write from/to a file
# TODO: add FileIO capabilities

## --.-..-..-- -- - - - . . .. .- - .- .-. .- . . .. -. - ..
# DONE: always return data, just add an empty!/flush method to reduce 
# DONE: Maybe rename to FileData
# :read -> file + data
# :write! -> file + data
# :get -> ?file + data
# :get! -> file + data
# :dry -> file + data

function __read(fn::String)
    # println("__read")
    # dir = dirname(fn)
    # isdir(dir) || mkpath(dir)
    deserialize(fn)
end
function __write(dat, fn::String)
    # println("__write")
    dir = dirname(fn)
    isdir(dir) || mkpath(dir)
    serialize(fn, dat)
end

## --.-..-..-- -- - - - . . .. .- - .- .-. .- . . .. -. - ..
# FileData Non Project based interface
_datio(f::Function, s::Symbol, arg0, args...) = 
    _datio(f, Val(s), arg0, args...)
_datio(s::Symbol, arg0, args...) = 
    _datio(Val(s), arg0, args...)

# read
# load + cache
function _datio(::Val{:read}, fn::String)
    dat = __read(fn)
    T = typeof(dat)
    return FileData{T}(fn, T[dat])
end
_datio(::Function, ::Val{:read}, fn::String) = 
    _datio(:read, fn)

# write!
# always write and cache
function _datio(::Val{:write!}, dat::T, fn::String) where T
    __write(dat, fn)
    return FileData{T}(fn, T[dat])
end
_datio(f::Function, ::Val{:write!}, fn::String) = 
    _datio(:write!, f(), fn)

# get
# load | dflt & cache
function _datio(f::Function, ::Val{:get}, fn::String)
    isfile(fn) && return _datio(:read, fn)
    dat = f()
    T = typeof(dat)
    return FileData{T}("", T[dat]) # Void link
end
_datio(::Val{:get}, fn::String) = 
    _datio(:read, fn)

# # write & get!
# # always write + cache
# function _datio(f::Function, ::Val{:wget!}, fn::String)
#     dat = f()
#     __write(dat, fn)
#     T = typeof(dat)
#     return FileData{T}(fn, T[dat])
# end

# get!
# maybe write and always load/cache
function _datio(f::Function, ::Val{:get!}, fn::String)
    return isfile(fn) ? _datio(:read, fn) : _datio(f, :write!, fn)
end

# dry!
# only cache
function _datio(f::Function, ::Val{:dry}, fn::String)
    dat = f()
    T = typeof(dat)
    return FileData{T}("", T[dat])
end

## --.-..-..-- -- - - - . . .. .- - .- .-. .- . . .. -. - ..
# fallbacks
function _datio(::Val{T}, _...) where T
    # _keys = [:read, :write!, :get, :wget!, :get!, :dry]
    _keys = [:read, :write!, :get, :get!, :dry]
    error("Unknown key $T, allowed: ", _keys)
end
_datio(a0, v::Val{T}, as...) where T = _datio(v, a0, as...)

## --.-..-..-- -- - - - . . .. .- - .- .-. .- . . .. -. - ..
# Base fn::String interface
# function _datio(f::Function, mode::Symbol, fn::String)
#     # read
#     # load + cache
#     if mode == :read
#         dat = __read(fn)
#         T = typeof(dat)
#         return FileData{T}(fn, T[dat])
#     end

#     # write!
#     # always write, no cache
#     if mode == :write!
#         dat = f()
#         __write(dat, fn)
#         T = typeof(dat)
#         return FileData{T}(fn, T[])
#     end

#     # get
#     # load | dflt & cache
#     if mode == :get
#         isfile(fn) && return _datio(_noop, :read, fn)
#         dat = f()
#         T = typeof(dat)
#         return FileData{T}("", T[dat]) # Void link
#     end

#     # write & get!
#     # always write + cache
#     if mode == :wget!
#         dat = f()
#         __write(dat, fn)
#         T = typeof(dat)
#         return FileData{T}(fn, T[dat])
#     end

#     # get!
#     # maybe write and always load/cache
#     if mode == :get!
#         isfile(fn) && return _datio(_noop, :read, fn) 
#         return _datio(f, :wget!, fn)
#     end

#     # dry!
#     # only cache
#     if mode == :dry
#         dat = f()
#         T = typeof(dat)
#         return FileData{T}("", T[dat])
#     end


# end
# _datio(s::Symbol, dat, fn::String) =
#     _datio(() -> dat, s, fn)
