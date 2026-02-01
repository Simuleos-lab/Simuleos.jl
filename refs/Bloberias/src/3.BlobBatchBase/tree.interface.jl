## --.-.--..-- - -- - - - -- . . . .. -. - - -- - 
# interface

_deflt_frameid_I(::BlobBatch) = "bb0"

_rootdir_I(bb::BlobBatch) = bb.root

_frames_depotdir_I(bb::BlobBatch) = bb.root

# return the frames depot
_frames_depot_I(bb::BlobBatch) = bb.frames

# most return (container, key)
function _depotpath_I(::BlobBatch, frameid::String, depot)
    return (depot, frameid)
end

# create and empty frame
function _mk_depotframe_I!(::BlobBatch, frameid::String, depot::Dict)
    get!(depot, frameid) do
        Dict{Union{UInt128, String}, Any}()
    end
    return nothing
end


# create the full path in the depot
function _mk_depotpath_I!(bb::BlobBatch, frameid::String, depot::Dict)
    _mk_depotframe_I!(bb, frameid, depot)
    return nothing
end

# check for blob path
function _has_depotpath_I(::BlobBatch, frameid::String, depot) 
    return haskey(depot, frameid) 
end


# use for trigger load 
function _frame_demand_load_I(bb::BlobBatch, frameid::String)
    haskey(bb.frames, frameid) && return false
    return true
end

# use for trigger serialization
function _frame_demand_serialization_I(bb::BlobBatch, frameid::String)
    haskey(bb.frames, frameid) && return true
    # TODO/ think about serializing empty frames
    # isempty(getindex(bb.frames, frameid)) && return false
    return false
end


## --.--. - .-. .- .--.-.- .- .---- ... . .-.-.-.- 
# serialization

function onserialize!(bb::BlobBatch, args...)
    
    # default up meta
    meta = getmeta(bb)
    meta["serialization.last.time"] = time()
    meta["blobs.cached.count"] = blobcount(bb)
    
    # custom callbacks
    run_callbacks((BlobBatch, "onserialize!"))

    return nothing
end

_is_serializable_I(::BlobBatch) = true

function _always_serialize_I(::BlobBatch, frameid) 
    frameid == "meta" && return true
    return false
end

## --.-.--..-- - -- - - - -- . . . .. -. - - -- - 
# Order is not garantied
import Base.getindex
function Base.getindex(bb::BlobBatch, idx::Int64)
    bch = eachblob(bb)
    tot = 0
    for (bi, b) in enumerate(bch)
        bi == idx && return b
        tot += 1
    end
    error("Index out of bound, idx: ", idx, ", tot: ", tot)
end