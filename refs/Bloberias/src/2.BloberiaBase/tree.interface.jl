## --.-.--..-- - -- - - - -- . . . .. -. - - -- - 
# interface

_deflt_frameid_I(::Bloberia) = "meta"

_rootdir_I(B::Bloberia) = B.root

_frames_depotdir_I(B::Bloberia) = B.root

# return the frames depot
_frames_depot_I(B::Bloberia) = B.frames

# most return (container, key)
function _depotpath_I(::Bloberia, frameid::String, depot) 
    return (depot, frameid)
end

# create an empty frame in the depot
function _mk_depotframe_I!(::Bloberia, frameid::String, depot::Dict)
    get!(depot, frameid) do
        Dict{String, Any}()
    end
    return nothing
end

# create the full path in the depot
function _mk_depotpath_I!(B::Bloberia, frameid::String, depot::Dict)
    _mk_depotframe_I!(B, frameid, depot)
    return nothing
end

# check for blob path
function _has_depotpath_I(::Bloberia, frameid::String, depot)
    return haskey(depot, frameid) 
end

# use for trigger load 
function _frame_demand_load_I(B::Bloberia, frameid::String)
    haskey(B.frames, frameid) && return false
    return true
end

# use for trigger serialization
function _frame_demand_serialization_I(B::Bloberia, frameid::String)
    haskey(B.frames, frameid) && return true
    # TODO/ think about serializing empty frames
    # isempty(getindex(B.frames, frameid)) && return false
    return false
end

# TODO: move to AbstractBlob
# - create an interface common for AbstractBlobs
# - control who can serialize! using _is_serializable_I(ab)::Bool interface
#   - add force kwarg to force

## --.--. - .-. .- .--.-.- .- .---- ... . .-.-.-.- 
function onserialize!(B::Bloberia, args...)
    
    # default up meta
    meta = getmeta(B)
    meta["serialization.last.time"] = time()
    
    # custom callbacks
    run_callbacks((Bloberia, "onserialize!"))

    return nothing
end

_is_serializable_I(::Bloberia) = true

function _always_serialize_I(::Bloberia, frameid) 
    frameid == "meta" && return true
    return false
end

## --.-.--..-- - -- - - - -- . . . .. -. - - -- - 
# MARK: Base.getindex
import Base.getindex
function Base.getindex(B::Bloberia, idx::Int64)
    bbch = eachbatch(B; sortfun = sort!)
    tot = 0
    for (bbi, bb) in enumerate(bbch)
        bbi == idx && return bb
        tot += 1
    end
    error("Index out of bound, idx: ", idx, ", tot:", tot)
end

function Base.getindex(B::Bloberia, pt::Regex)
    # search in batch
    found = findbatch(B, nothing, nothing) do _bb
        m = match(pt, _bb.id)
        isnothing(m) && return false
        return true
    end
    isnothing(found) || return found
    # search in blob (?)

    return found
end
