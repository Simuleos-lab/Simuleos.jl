## --.--. - .-. .- .--.-.- .- .---- ... . .-.-.-.- 
# _deref_cached(src::Blob, ref::BlobyRef{:Val, rT}) where rT =
#     getindex(b, ref.link["val.frame"]::String, ref.link["val.key"]::String)::rT
# _deref_blobval(bb::BlobBatch, ref::BlobyRef{:Val, rT}) where rT =
#     _deref_blobval(_deref_blob(bb, ref), ref)
# _deref_blobval(B::Bloberia, ref::BlobyRef{:Val, rT}) where rT =
#     _deref_blobval(_deref_blobbatch(B, ref), ref)

function deref(rc::RefCacher, ref::BlobyRef)
    # load from cache
    roothash = deref_depothash(ref)
    if haskey(rc.depot_cache, roothash)
        ab = rc.depot_cache[roothash]
        # @info "Hi" typeof(ab) roothash
        return deref(ab, ref)
    end
    # up cache
    ab = deref_depotblob(ref)
    # TODO implement variable size cache
    empty!(rc.depot_cache) # TODO implement variable size cache
    setindex!(rc.depot_cache, ab, roothash)
    return deref(ab, ref)
end