## --.-.--..-- - -- - - - -- . . . .. -. - - -- - 
#MARK: hasframe

# check for frame in depot
# A frame is a node the blobtree.
# A subtree from this node is exactly contain in the disk version of the blobtree.
function _hasframe_depot(ab::AbstractBlob, frameid::String) 
    depot = _frames_depot_I(ab)
    return haskey(depot, frameid) 
end

function _empty_depot!(ab::AbstractBlob)
    depot = _frames_depot_I(ab)
    empty!(depot)
end

# This is the  main method for the blobtree interface
# It returns a depot obj (a dict) and an index which defines a full path
# to a blob.
# Here the path is parametrize by an AbstractBlob object and  a frameid.
function _depotpath_I(ab::AbstractBlob, frameid::String) 
    return _depotpath_I(ab, frameid, _frames_depot_I(ab))
end

function _has_depotpath_I(ab::AbstractBlob, frameid::String)
    return _has_depotpath_I(ab, frameid, _frames_depot_I(ab))
end

# populate a path on the blob tree
function _mk_depotpath_I!(ab::AbstractBlob, frameid::String)
    return _mk_depotpath_I!(ab, frameid, _frames_depot_I(ab))
end

function _mk_depotframe_I!(ab::AbstractBlob, frameid::String)
    return _mk_depotframe_I!(ab, frameid, _frames_depot_I(ab))
end

## --.-.--..-- - -- - - - -- . . . .. -. - - -- - 
# accessors
#MARK: frame depot

# getindex on depot frame
function _getindex_depot_frame(ab::AbstractBlob, frameid::String)
    depot = _frames_depot_I(ab)
    return getindex(depot, frameid)
end

# setindex on depot frame
function _setindex_depot_frame!(depot::Dict, frameid::String, dat::Dict)
    setindex!(depot, dat, frameid)
end

function _setindex_depot_frame!(ab::AbstractBlob, frameid::String, dat::Dict)
    return _setindex_depot_frame!(_frames_depot_I(ab), frameid, dat)
end

# get on depot frame
function _get_depot_frame(dflt::Function, ab::AbstractBlob, frameid::String)
    depot = _frames_depot_I(ab)
    get(dflt, depot, frameid)
end

# get! on depot frame
function _get_depot_frame!(dflt::Function, ab::AbstractBlob, frameid::String)
    depot = _frames_depot_I(ab)
    get!(dflt, depot, frameid)
end

## --.-.--..-- - -- - - - -- . . . .. -. - - -- - 
# accessor
#MARK: blob depot

function _depot_blob(ab::AbstractBlob, frameid::String, onmiss = nothing)
    _has_depotpath_I(ab, frameid) || return onmiss
    _depot, _base = _depotpath_I(ab, frameid) 
    _blob = getindex(_depot, _base)::Dict
    return _blob
end

function _depot_blob!(ab::AbstractBlob, frameid::String)
    _has_depotpath_I(ab, frameid) || _mk_depotpath_I!(ab, frameid)
    _depot, _base = _depotpath_I(ab, frameid)
    _blob = getindex(_depot, _base)::Dict
    return _blob
end

function _getindex_depot_blob(ab::AbstractBlob, frameid::String, key::String)
    _depot, _base = _depotpath_I(ab, frameid) 
    _blob = getindex(_depot, _base)
    return getindex(_blob, key)
end

function _setindex_depot_blob!(ab::AbstractBlob, val, frameid::String, key::String)
    _mk_depotpath_I!(ab, frameid)
    _depot, _base = _depotpath_I(ab, frameid)
    _blob = getindex(_depot, _base)::Dict
    return setindex!(_blob, val, key)
end

function _get_depot_blob(dflt::Function, ab::AbstractBlob, frameid::String, key::String)
    _has_depotpath_I(ab, frameid) || return dflt()
    _depot, _base = _depotpath_I(ab, frameid) 
    _blob = getindex(_depot, _base)::Dict
    return get(dflt, _blob, key)
end

function _get_depot_blob!(dflt::Function, ab::AbstractBlob, frameid::String, key::String)
    _mk_depotpath_I!(ab, frameid)
    _depot, _base = _depotpath_I(ab, frameid)
    _blob = getindex(_depot, _base)::Dict
    return get!(dflt, _blob, key)
end

