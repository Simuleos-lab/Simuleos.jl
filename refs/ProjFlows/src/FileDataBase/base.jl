_file(ref::AbstractFileRef) = getfield(ref, :file)
_cache(ref::FileData) = getfield(ref, :cache)

import Base.rm
Base.rm(ref::AbstractFileRef; kwargs...) = rm(_file(ref); kwargs...)

import Base.isfile
Base.isfile(ref::AbstractFileRef) = isfile(_file(ref))

import Base.empty!
Base.empty!(ref::FileData) = empty!(_cache(ref)) 

import Base.isempty
Base.isempty(ref::FileData) = isempty(_cache(ref))

import Base.getindex
function Base.getindex(ref::FileRef{T})::T where T 
    __read(_file(ref))
end

function Base.getindex(ref::FileData{T})::T where T
    if isempty(_cache(ref)) # cache
        _dat = __read(_file(ref))
        push!(_cache(ref), _dat)
        return _dat
    end
    return first(_cache(ref))
end

# TODO: implement setindex!

import Base.show
function Base.show(io::IO, ref::FileData{T}) where T
    println(io, "FileData", "{", T, "}")
    println(io, "   file: ", _file(ref))
    print(io, "   has_cache: ", !isempty(_cache(ref)))
end

function Base.show(io::IO, ref::FileRef{T}) where T
    println(io, "FileRef", "{", T, "}")
    print(io, "   file: ", _file(ref))
end

# iteration for destructuring into components
Base.iterate(ref::AbstractFileRef) = (_file(ref), Val(:data))
Base.iterate(ref::AbstractFileRef, ::Val{:data}) = (ref[], Val(:done))
Base.iterate(::AbstractFileRef, ::Val{:done}) = nothing

import Base.getproperty
function Base.getproperty(ref::AbstractFileRef, sym::Symbol)
    if sym === :file
        return _file(ref)
    elseif sym === :data
        return ref[]
    else # fallback to getfield
        return getfield(ref, sym)
    end
end

import Base.propertynames
Base.propertynames(::FileRef, _...) = [:file, :data]
Base.propertynames(::FileData, _...) = [:file, :data, :cache]