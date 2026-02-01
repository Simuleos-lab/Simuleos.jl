## --.--. - .-. .- .--.-.- .- .---- ... . .-.-.-.- 
# TODO Document this

## --.--. - .-. .- .--.-.- .- .---- ... . .-.-.-.- 
# - a reference if just a recipe for createing/indexing a blobyobj
# - it do not check if information exist
# - that is, invalid references/blobyobjs can be produce

## --.--. - .-. .- .--.-.- .- .---- ... . .-.-.-.- 
# Abstract interface 

deref_depothash(ref::BlobyRef) = deref_srchash(ref)

deref_depotblob(ref::BlobyRef) = deref_srcblob(ref)

## --.--. - .-. .- .--.-.- .- .---- ... . .-.-.-.- 
# Bloberia

# unsafe
_deref_bloberiapath(ref::BlobyRef) = ref.link["B.root"]::String
_deref_bloberia(ref::BlobyRef) = Bloberia(_deref_bloberiapath(ref))
_deref_bloberia(B::Bloberia, ::BlobyRef) = B

function _refhash_B(ref::BlobyRef, h0 = UInt(0)) 
    h = hash(ref.link["B.root"], h0)
    return h
end

# public interface
deref(ref::BlobyRef{:Bloberia, Bloberia}) = _deref_bloberia(ref)
deref(B::Bloberia, ::BlobyRef{:Bloberia, Bloberia}) = B

deref_srcblob(ref::BlobyRef{:Bloberia, Bloberia}) = _deref_bloberia(ref)

deref_srchash(ref::BlobyRef{:Bloberia, Bloberia}) = _refhash_B(ref)

bloberia(ref::BlobyRef{:Bloberia, Bloberia}) = _deref_bloberia(ref)
blobbatch(::BlobyRef{:Bloberia, Bloberia}) = nothing

## --.--. - .-. .- .--.-.- .- .---- ... . .-.-.-.- 
# BlobBatch

# unsafe
_deref_batchpath(ref::BlobyRef) = _batchpath(_deref_bloberiapath(ref), ref.link["bb.id"]::String)

_deref_blobbatch(B::Bloberia, ref::BlobyRef) = blobbatch!(B, ref.link["bb.id"]::String)
_deref_blobbatch(bb::BlobBatch, ::BlobyRef) = bb
_deref_blobbatch(ref::BlobyRef) = _deref_blobbatch(_deref_bloberia(ref), ref)

function _refhash_bb(ref::BlobyRef, h0 = UInt(0)) 
    h = _refhash_B(ref, h0)
    h = hash(ref.link["bb.id"], h)
    return h
end

# public interface
deref(ref::BlobyRef{:BlobBatch, BlobBatch}) = _deref_blobbatch(ref)
deref(bb::BlobBatch, ::BlobyRef{:BlobBatch, BlobBatch}) = bb
deref(B::Bloberia, ref::BlobyRef{:BlobBatch, BlobBatch}) = _deref_blobbatch(B, ref)

deref_srcblob(ref::BlobyRef{:BlobBatch, BlobBatch}) = _deref_blobbatch(ref)
deref_srchash(ref::BlobyRef{:BlobBatch, BlobBatch}) = _refhash_bb(ref)

bloberia(ref::BlobyRef{:BlobBatch, BlobBatch}) = _deref_bloberia(ref)
blobbatch(ref::BlobyRef{:BlobBatch, BlobBatch}) = _deref_blobbatch(ref)

## --.--. - .-. .- .--.-.- .- .---- ... . .-.-.-.- 
# bBlob

# unsafe
_deref_blob(b::bBlob, ::BlobyRef) = b 
_deref_blob(bb::BlobBatch, ref::BlobyRef) = blob!(bb, ref.link["b.uuid"]::UInt128)
_deref_blob(B::Bloberia, ref::BlobyRef) = _deref_blob(_deref_blobbatch(B, ref), ref)
_deref_blob(ref::BlobyRef) = _deref_blob(_deref_blobbatch(ref), ref)

function _refhash_b(ref::BlobyRef, h0 = UInt(0)) 
    h = _refhash_bb(ref, h0)
    h = hash(ref.link["b.uuid"], h)
    return h
end

# public interface
deref(ref::BlobyRef{:bBlob, bBlob}) = _deref_blob(ref)
deref(bb::BlobBatch, ref::BlobyRef{:bBlob, bBlob}) =  _deref_blob(bb, ref)
deref(B::Bloberia, ref::BlobyRef{:bBlob, bBlob}) =  _deref_blob(B, ref)
deref(b::bBlob, ::BlobyRef{:bBlob, bBlob}) = b

# the root blob is the original BlobyObject
deref_srcblob(ref::BlobyRef{:bBlob, bBlob}) = _deref_blob(ref)
deref_srchash(ref::BlobyRef{:bBlob, bBlob}) = _refhash_b(ref)

bloberia(ref::BlobyRef{:bBlob, bBlob}) = _deref_bloberia(ref)
blobbatch(ref::BlobyRef{:bBlob, bBlob}) = _deref_blobbatch(ref)
blob(ref::BlobyRef{:bBlob, bBlob}) = _deref_blob(ref)

## --.--. - .-. .- .--.-.- .- .---- ... . .-.-.-.- 
# Val

# val owner
function __case_source(ref::BlobyRef, _bcase, _bbcase, _Bcase)
    ow = get(ref.link, "src", nothing)
    ow == "b" && return _bcase(ref)
    ow == "bb" && return _bbcase(ref)
    ow == "B" && return _Bcase(ref)
    error("Source is missing!!")
end

# unsave
# A val ref will keep the type of the src blob
__deref_val(ab::AbstractBlob, ref::BlobyRef{:Val, rT}) where rT =
    getindex(ab, ref.link["val.frame"]::String, ref.link["val.key"]::String)::rT

_deref_blobval(ref::BlobyRef) =
    __deref_val(deref_srcblob(ref), ref)
function _deref_blobval(ab::AbstractBlob, ref::BlobyRef)
    _src = __case_source(ref, 
        (_ref) -> _deref_blob(ab, _ref), 
        (_ref) -> _deref_blobbatch(ab, _ref), 
        (_ref) -> _deref_bloberia(ab, _ref), 
    )
    __deref_val(_src, ref)
end

# public interface
deref(ref::BlobyRef{:Val, rT}) where rT = _deref_blobval(ref)
deref(b::bBlob, ref::BlobyRef{:Val, rT}) where rT = _deref_blobval(b, ref)
deref(bb::BlobBatch, ref::BlobyRef{:Val, rT}) where rT = _deref_blobval(bb, ref)
deref(B::Bloberia, ref::BlobyRef{:Val, rT}) where rT = _deref_blobval(B, ref)

deref_srcblob(ref::BlobyRef{:Val, rT}) where rT =
    __case_source(ref, _deref_blob, _deref_blobbatch, _deref_bloberia)

deref_srchash(ref::BlobyRef{:Val, rT}) where rT =
    __case_source(ref, _refhash_b, _refhash_bb, _refhash_B)

deref_depothash(ref::BlobyRef{:Val, rT}) where rT =
    __case_source(ref, _refhash_bb, _refhash_bb, _refhash_B)

deref_depotblob(ref::BlobyRef{:Val, rT}) where rT =
    __case_source(ref, blobbatch, blobbatch, bloberia)

bloberia(ref::BlobyRef{:Val, rT}) where rT = _deref_bloberia(ref)
blobbatch(ref::BlobyRef{:Val, rT}) where rT = _deref_blobbatch(ref)
blob(ref::BlobyRef{:Val, rT}) where rT = _deref_blob(ref)
    
