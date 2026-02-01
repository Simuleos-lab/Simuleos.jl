## --------------------------------------------------------
import Base.empty!
function Base.empty!(bb::BlobBatch)
    empty!(bb.frames)
    return bb
end

## --------------------------------------------------------
import Base.isempty
function Base.isempty(bb::BlobBatch)
    # check ram
    for key in keys(bb.frames)
        key == "temp" && continue
        key == "meta" && isempty(bb["meta"]) && continue
        return false # a frame was created or meta has something
    end
    # check disk
    hasfilesys(bb) || return true
    isdir(bb) || return true
    return isempty(framefiles(bb))
end

## --------------------------------------------------------
import Base.merge!
function Base.merge!(bb0::BlobBatch, bb1::BlobBatch)
    merge!(bb0.frames, bb1.frames)
end

## --------------------------------------------------------
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

## --------------------------------------------------------
import Base.show
function Base.show(io::IO, bb::BlobBatch)
    println(io, "BlobBatch")
    if hasfilesys(bb)
        println(io,     " rootdir          \"", rootdir(bb), "\"")
        if isdir(bb)
            val, unit = _canonical_bytes(filesize(bb))
            println(io, " disk used         ", round(val; digits = 3), " ", unit)
        end
    else
        println(io,     " no file system    ")
    end

    # batchmeta
    if !isempty(bb["meta"])
        println(io,     " meta keys        [", _quoted_join(keys(bb["meta"]), ", "), "]")
    end

    # loaded frames
    loaded = filter(keys(bb.frames)) do key
        key != "temp" && key != "meta"
    end
    if !isempty(loaded)
        println(io,     " loaded frames    [", _quoted_join(loaded, ", "), "]")
    end

    # on disk
    # @show framefiles(bb)
    if isdir(bb)
        onDisk = filter(framefiles(bb)) do fn
            key = _framekey_from_path(fn)
            key != "temp" && key != "meta"
        end
        if !isempty(onDisk)
            println(io,     " ondisk frames    [", _quoted_join(basename.(onDisk), ", "), "]")
        end
    end

end
show(bb::BlobBatch) = show(stdout, bb)
