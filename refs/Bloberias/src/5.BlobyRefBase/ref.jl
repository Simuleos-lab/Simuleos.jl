## --.--. - .-. .- .--.-.- .- .---- ... . .-.-.-.- 
# Bloberia

function _upref_I!(ref::BlobyRef, B::Bloberia, frame, key)
    ref.link["B.root"] = bloberiapath(B)
    isnothing(frame) && return ref
    ref.link["val.frame"] = frame
    ref.link["val.key"] = key
    return ref
end

# creates a ref to a Bloberia
function _blobyref_I(B::Bloberia; abs = true)
    ref = BlobyRef(:Bloberia, Bloberia)
    _upref_I!(ref, B, nothing, nothing)
    ref.link["src"] = "B"
    return ref
end

## --.--. - .-. .- .--.-.- .- .---- ... . .-.-.-.- 
# BlobBatch
function _upref_I!(ref::BlobyRef, bb::BlobBatch, frame, key)
    ref.link["bb.id"] = bb.id
    isnothing(frame) && return ref
    ref.link["val.frame"] = frame
    ref.link["val.key"] = key
    return ref
end

function _blobyref_I(bb::BlobBatch; abs = true)
    ref = BlobyRef(:BlobBatch, BlobBatch)
    abs && _upref_I!(ref, bb.B, nothing, nothing)
    _upref_I!(ref, bb, nothing, nothing)
    ref.link["src"] = "bb"
    return ref
end

## --.--. - .-. .- .--.-.- .- .---- ... . .-.-.-.- 
# bBlob

function _upref_I!(ref::BlobyRef, b::bBlob, frame, key)
    ref.link["b.uuid"] = b.uuid
    isnothing(frame) && return ref
    ref.link["val.frame"] = frame
    ref.link["val.key"] = key
    return ref
end

# :bBlob
function _blobyref_I(b::bBlob; abs = true)
    ref = BlobyRef(:bBlob, bBlob)
    abs && _upref_I!(ref, b.bb.B, nothing, nothing)
    abs && _upref_I!(ref, b.bb, nothing, nothing)
    _upref_I!(ref, b, nothing, nothing)
    ref.link["src"] = "b"
    return ref
end

# --.--. - .-. .- .--.-.- .- .---- ... . .-.-.-.- 
# :Val

function _blobyref_I(B::Bloberia, frame, key; rT = Any, abs = true)
    ref = BlobyRef(:Val, rT)
    _upref_I!(ref, B, frame, key)
    ref.link["src"] = "B"
    return ref
end

function _blobyref_I(bb::BlobBatch, frame, key; rT = Any, abs = true)
    ref = BlobyRef(:Val, rT)
    abs && _upref_I!(ref, bb.B, nothing, nothing)
    _upref_I!(ref, bb, frame, key)
    ref.link["src"] = "bb"
    return ref
end

function _blobyref_I(b::bBlob, frame, key; rT = Any, abs = true)
    ref = BlobyRef(:Val, rT)
    abs && _upref_I!(ref, b.bb.B, nothing, nothing)
    abs && _upref_I!(ref, b.bb, nothing, nothing)
    _upref_I!(ref, b, frame, key)
    ref.link["src"] = "b"
    return ref
end

# --.--. - .-. .- .--.-.- .- .---- ... . .-.-.-.- 
# public interface

function blobyref(ab::AbstractBlob; abs = true)
    _blobyref_I(ab; abs)
end

function blobyref(ab::AbstractBlob, frameid, key; rT = Any, abs = true)
    _blobyref_I(ab, frameid, key; rT, abs)
end
function blobyref(ab::AbstractBlob, key; rT = Any, abs = true)
    frameid = dflt_frameid(ab)
    _blobyref_I(ab, frameid, key; rT, abs)
end