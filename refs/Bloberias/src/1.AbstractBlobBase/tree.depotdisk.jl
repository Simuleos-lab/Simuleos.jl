## --.-.--..-- - -- - - - -- . . . .. -. - - -- - 
# hasframe

function _hasframe_depotdisk(ab::AbstractBlob, frameid::String) 
    _hasframe_depot(ab, frameid) && return true
    _hasframe_disk(ab, frameid) && return true
    return false
end

## --.-.--..-- - -- - - - -- . . . .. -. - - -- - 
# load frames

# load frame into depot
function _load_frame!(ab::AbstractBlob, frameid::String)
    dat = _deserialize_frame(ab, frameid)
    _setindex_depot_frame!(ab, frameid, dat)
    return nothing
end

# load frame into depot
# if not in disk, load dflt()
function _load_frame!(dflt::Function, ab::AbstractBlob, frameid::String)
    # try file
    if _hasframe_disk(ab, frameid) 
        return _load_frame!(ab, frameid)
    end
    _setindex_depot_frame!(ab, frameid, dflt())
    return nothing
end

# errorless version of _ondemand_load_frame!
function _try_load_frame!(ab::AbstractBlob, frameid::String)
    _hasframe_disk(ab, frameid) && _load_frame!(ab, frameid)
    return nothing
end

function _ondemand_load_frame!(ab::AbstractBlob, frameid::String)
    _frame_demand_load_I(ab, frameid) || return nothing
    _load_frame!(ab, frameid)
end

function _ondemand_load_frame!(dflt::Function, ab::AbstractBlob, frameid::String)
    _frame_demand_load_I(ab, frameid) || return nothing
    _load_frame!(dflt, ab, frameid)
end

# errorless version of _ondemand_load_frame!
function _ondemand_try_load_frame!(ab::AbstractBlob, frameid::String)
    _frame_demand_load_I(ab, frameid) || return nothing
    _try_load_frame!(ab, frameid)
    return nothing
end

## --.-.--..-- - -- - - - -- . . . .. -. - - -- - 
# frame load mk

# errorless version of _ondemand_load_frame!
function _ondemand_try_loadmk_frame!(ab::AbstractBlob, frameid::String)
    _frame_demand_load_I(ab, frameid) || return nothing
    _try_load_frame!(ab, frameid)
    _hasframe_depot(ab, frameid) && return nothing
    _mk_depotpath_I!(ab, frameid)
    return nothing
end

## --.-.--..-- - -- - - - -- . . . .. -. - - -- - 
# frame disk/ram accessors

# look for frame first at depot later at file
function _depotdisk_frame(ab::AbstractBlob, frameid::String)
    # try depot
    if _hasframe_depot(ab, frameid) 
        depot = _frames_depot_I(ab)
        return getindex(depot, frameid)
    end
    
    # try file
    return _deserialize_frame(ab, frameid)
end

# look for frame first at depot later at file
function _get_depotdisk_frame(dflt::Function, ab::AbstractBlob, frameid::String)
    # try depot
    if _hasframe_depot(ab, frameid) 
        depot = _frames_depot_I(ab)
        return getindex(depot, frameid)
    end
    
    # try file
    if _hasframe_disk(ab, frameid) 
        return _deserialize_frame(ab, frameid)
    end

    # dflt
    return dflt()
end

# look for frame first at depot later at file
# if miss, store dflt() on depot
function _get_depotdisk_frame!(dflt::Function, ab::AbstractBlob, frameid::String)
    # try depot
    if _hasframe_depot(ab, frameid) 
        depot = _frames_depot_I(ab)
        return getindex(depot, frameid)
    end
    
    # try file
    if _hasframe_disk(ab, frameid) 
        return _deserialize_frame(ab, frameid)
    end

    # dflt
    dat = dflt()::Dict
    _setindex_depot_frame!(ab, frameid, dat)
    return dat
end


## --.-.--..-- - -- - - - -- . . . .. -. - - -- - 
# blob disk/ram accessors

# function _getindex_depot_blob(ab::AbstractBlob, frameid::String, key::String)
function _getindex_depotdisk_blob(ab::AbstractBlob, frameid::String, key::String)
    _ondemand_try_load_frame!(ab, frameid)
    return _getindex_depot_blob(ab, frameid, key)
end

function _setindex_depotdisk_blob!(ab::AbstractBlob, val, frameid::String, key::String)
    _ondemand_try_load_frame!(ab, frameid)
    return _setindex_depot_blob!(ab, val, frameid, key)
end

function _get_depotdisk_blob(dflt::Function, ab::AbstractBlob, frameid::String, key::String)
    _ondemand_try_load_frame!(ab, frameid)
    return _get_depot_blob(dflt, ab, frameid, key)
end

function _get_depotdisk_blob!(dflt::Function, ab::AbstractBlob, frameid::String, key::String)
    _ondemand_try_load_frame!(ab, frameid)
    return _get_depot_blob!(dflt, ab, frameid, key)
end

## --.-.--..-- - -- - - - -- . . . .. -. - - -- - 
# serialization

function _serialize_depot_frame(ab::AbstractBlob, frameid::String)
    dat = _getindex_depot_frame(ab, frameid)
    path = _frame_filepath(ab, frameid)
    _serialize_frame(path, dat)
end

function _ondemand_serialize_depot_frame(ab::AbstractBlob, frameid::String)
    _frame_demand_serialization_I(ab, frameid) || return nothing
    dat = _getindex_depot_frame(ab, frameid)
    path = _frame_filepath(ab, frameid)
    _serialize_frame(path, dat)
end
