## --.-.--..-- - -- - - - -- . . . .. -. - - -- - 
# interface

_deflt_frameid_I(::bBlob) = "b0"

_frames_depotdir_I(b::bBlob) = _frames_depotdir_I(b.bb)

# return the frames depot
_frames_depot_I(b::bBlob) = _frames_depot_I(b.bb)

# most return (container, key)
function _depotpath_I(b::bBlob, frameid::String, depot) 
    _depot, _base = _depotpath_I(b.bb, frameid, depot)
    _bb_frame = getindex(_depot, _base)
    return (_bb_frame, b.uuid)
end

# create and empty frame
_mk_depotframe_I!(b::bBlob, frameid::String, depot::Dict) =
    _mk_depotframe_I!(b.bb, frameid, depot)

# create the full path in the depot
function _mk_depotpath_I!(b::bBlob, frameid::String, depot::Dict)
    _mk_depotframe_I!(b.bb, frameid, depot)
    _depot, _base = _depotpath_I(b.bb, frameid, depot)
    _bb_frame = getindex(_depot, _base)
    get!(_bb_frame, b.uuid) do
        Dict{String, Any}()
    end
    return nothing
end

# check for blob path
function _has_depotpath_I(b::bBlob, frameid::String, depot)
    _has_depotpath_I(b.bb, frameid, depot) || return false
    _depot, _base = _depotpath_I(b.bb, frameid, depot)
    _bb_frame = getindex(_depot, _base)
    haskey(_bb_frame, b.uuid) || return false
    return true
end

# use for trigger load 
function _frame_demand_load_I(b::bBlob, frameid::String)
    return _frame_demand_load_I(b.bb, frameid)
end

_is_serializable_I(::bBlob) = false
_serializable_blob_I(b::bBlob) = b.bb