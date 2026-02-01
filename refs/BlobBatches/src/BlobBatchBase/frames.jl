## --------------------------------------------------------
_framekey(k::Number) = string(k)
_framekey(k::AbstractString) = string(k)
_framekey(k::Symbol) = string(k)
__framekey(ks...) = (_framekey(k) for k in ks)
framekey(k, ks...) = join(__framekey(k, ks...), "..")

function __walkup_framekey(f::Function, ks...)
    i0 = firstindex(ks)
    i1 = lastindex(ks)
    i = i0
    while i <= i1
        f(framekey(ks[i0:i]...)) === true && return nothing # short
        i += 1
    end
end

## --------------------------------------------------------
function __frame_notfound_err(bb::BlobBatch, k, ks...)
    key0 = framekey(k, ks...)
    msg = String[
        "Frame not found, framekey: \"", key0, "\"", 
    ]
    sims = String[]
    for key in keys(bb.frames)
        if contains(key0, key) || contains(key, key0)
            push!(sims, key)
        end
    end
    if !isempty(sims)
        push!(msg, string(", similars: ", _quoted_join(sims, ", ")))
    end
    error(join(msg))
end

## --------------------------------------------------------
# check both ram and disk
function hasframe(bb::BlobBatch, k, ks...)
    key = framekey(k, ks...)
    # check file is loaded
    haskey(bb.frames, key) && return true
    # check in disk
    hasfilesys(bb) || return false
    isfile(bb, key) || return false
    return true
end

# import Base.haskey
# Base.haskey(bb::BlobBatch, k, ks...) = haskey(bb.frames, k, ks...)

## --------------------------------------------------------
# get frame
function _getindex(bb::BlobBatch, key::String)
    # temp
    key == "temp" && return get!(() -> Dict{String, Any}(), bb.frames, key)
    if !hasframe(bb, key) # check both ram and disk
        # meta
        key == "meta" && return get!(() -> Dict{String, Any}(), bb.frames, key)
        # error
        __frame_notfound_err(bb, key)
    end
    if !isframeloaded(bb, key) # load if needed
        bb.frames[key] = deserialize(framefile(bb, key))
    end
    return getindex(bb.frames, key)
end

import Base.getindex
Base.getindex(bb::BlobBatch, k, ks...) = _getindex(bb, framekey(k, ks...))

## --------------------------------------------------------
function _find_prefixkey(bb::BlobBatch, k, ks...)
    # check shadowing
    key = ""
    __walkup_framekey(k, ks...) do _key
        if haskey(bb.frames, _key)
            key = _key
            return true # short
        end
        return false
    end
    return key
end

## --------------------------------------------------------
# create frame
# TODO?: Restrict frame types AbstractDict, AbstractArray
import Base.setindex!
function Base.setindex!(bb::BlobBatch, val::Any, k, ks...)
    key = framekey(k, ks...)
    # check prefix key
    # skey = _find_prefixkey(bb, k, ks...)
    # !isempty(skey) && skey != key && error("Frames cannot share prefix: framekey: ", key, ", existing: ", skey)
    # check reserved
    if key == "meta" || key == "temp"
        error("Can not set a reserved frame, framekey: ", key)
    end
    # create frame
    return setindex!(bb.frames, val, key)
end

## --------------------------------------------------------
# delete! a frame from ram, do not affect disk
function unloadframe!(bb::BlobBatch, k, ks...)
    key = framekey(k, ks...)
    val = bb.frames[key]
    delete!(bb.frames, key)
    return val
end

# load frame from disk
function loadframe!(bb::BlobBatch, k, ks...)
    key = framekey(k, ks...)
    bb.frames[key] = deserialize(framefile(bb, key))
    return bb.frames[key]
end

# assumes is valid bb file
_framekey_from_path(path) = basename(path)[1:(end - length(_BLOBBATCH_FRAME_EXT))]


function loadallframe!(bb::BlobBatch)
    for fn in framefiles(bb)
        key = _framekey_from_path(fn)
        # reserved
        key == "temp" && continue # ignore temp
        loadframe!(bb, key)
    end
end

isframeloaded(bb::BlobBatch, k, ks...) = haskey(bb.frames, framekey(k, ks...))