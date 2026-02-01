## --.-.--..-- - -- - - - -- . . . .. -. - - -- - 
# File sys

_frame_filepath(root::String, frameid::String) = 
            joinpath(root, string(frameid, ".frame.jls"))

function _frame_filepath(ab::AbstractBlob, frameid::String)
    return gettemp!(ab, frameid) do
        _frame_filepath(_frames_depotdir_I(ab), frameid)
    end
end

function _is_frame_filepath(file::String)
    endswith(file, ".frame.jls") || return false
    return true
end

function _frameid_from_file(file::String)
    frameid = basename(file)
    frameid = replace(frameid, ".frame.jls" => "")
    return frameid
end

function _diskframes(ab::AbstractBlob; join = false, sort = false)
    dir = _frames_depotdir_I(ab)
    frames = String[]
    isdir(dir) || return frames
    for file in readdir(dir; join, sort)
        _is_frame_filepath(file) || continue
        frameid = _frameid_from_file(file)
        push!(frames, frameid)
    end
    return frames
end

function _with_diskframes(fun::Function, ab::AbstractBlob)
    frames = _diskframes(ab; join = false)
    for frameid in frames
        fun(frameid) === :break && break
    end
end

function _depotframes(ab::AbstractBlob)
    return keys(_frames_depot_I(ab))
end

function _with_depotframes(fun::Function, ab::AbstractBlob)
    frameids = _depotframes(ab)
    for frameid in frameids
        fun(frameid) === :break && break
    end
end
            
## --.-.--..-- - -- - - - -- . . . .. -. - - -- - 
# hasframe

function _hasframe_disk(ab::AbstractBlob, frameid::String) 
    path = _frame_filepath(ab, frameid)
    return isfile(path)
end

## --.-.--..-- - -- - - - -- . . . .. -. - - -- - 
# serialization

function _serialize_frame(path::String, dat::Dict)
    _mkpath(path)
    serialize(path, dat)
end

function _deserialize_frame(fpath::String)
    return deserialize(fpath)
end

function _serialize_frame(ab::AbstractBlob, frameid::String, dat::Dict)
    path = _frame_filepath(ab, frameid)
    _serialize_frame(path, dat)
end

function _deserialize_frame(ab::AbstractBlob, frameid::String)
    path = _frame_filepath(ab, frameid)
    return _deserialize_frame(path)
end

function _serialize_frames!(fil::Function, ab::AbstractBlob)
    _with_depotframes(ab) do frameid
        fil(frameid) === true || return :continue
        _serialize_depot_frame(ab, frameid)
    end
end

## --.-.--..-- - -- - - - -- . . . .. -. - - -- - 
# access disk blobs

function _disk_blob(ab::AbstractBlob, frameid::String, onmiss)
    _hasframe_disk(ab, frameid) || return onmiss
    _frames_depot = Dict() # temp frame depot
    dat = _deserialize_frame(ab, frameid)
    _setindex_depot_frame!(_frames_depot, frameid, dat)
    _has_depotpath_I(ab, frameid, _frames_depot) || return onmiss
    _depot, _base = _depotpath_I(ab, frameid, _frames_depot) 
    _blob = getindex(_depot, _base)::Dict
    return _blob
end