## --------------------------------------------------------
import Serialization.serialize
function Serialization.serialize(bb::BlobBatch)
    for (fkey, dat) in bb.frames
        # ignore empty meta
        fkey == "meta" && isempty(dat) && continue
        # handle reserved
        fkey == "temp" && continue
        mkpath(bb)
        serialize(framefile(bb, fkey), dat)
    end
end

function Serialization.serialize(bb::BlobBatch, k, ks...)
    key = framekey(k, ks...)
    key == "temp" && error("\"temp\" is reserved, do not serialize it!")
    mkpath(bb)
    serialize(framefile(bb, key), bb[key])
    nothing
end

import Serialization.deserialize
# load all frames
function Serialization.deserialize(::Type{BlobBatch}, dir::AbstractString)
    bb = BlobBatch(dir)
    loadallframe!(bb)
    return bb
end

deserialize!(bb::BlobBatch, k, ks...) = loadframe!(bb, k, ks...)