# At load on demand
# - the object will ask its parents to also load on demand

using JSON3

# It must return a Dict like object
function _read_jsonline(path::String)
    isfile(path) || return nothing
    return open(path, "r") do io
        JSON3.read(io; jsonlines = true)
    end
end

function _diskfile(bt::LiteTapeSegment)
    return bt.path
end

# Return a new diskdepot object
function _read_diskdepot(bt::LiteTapeSegment)
    # load jsonline
    return _read_jsonline(_diskfile(bt))
end

# Will unlink all blobs
# that is, any ram work will be lost
function _hardload_diskdepot!(bt::LiteTapeSegment, doempty=true)
    _disk_batch = _read_jsonline(_diskfile(bt))
    isnothing(_disk_batch) && return
    doempty && empty!(bt)
    for dat in _disk_batch
        tbl = LiteTapeRecord(bt, dat)
        LiteRecords._lite_push!(bt, tbl)
    end
end

function _ondemand_hardload_diskdepot!(bt::LiteTapeSegment)
    println("_ondemand_hardload_diskdepot!")
    # check demand
    isempty(bt) || return
    # load disk
    _hardload_diskdepot!(bt, false)
end