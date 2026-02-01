## .- .- .. . .. . - - -  - . - .. --. .- -..- -
# MARK: lite interface
# Overwrite base methods to include disk handling

# Will unlink all blobs
# that is, any ram work will be lost
function _hardload_diskdepot!(bt::LiteTapeRecord, doempty=true)
    _disk_batch = _read_jsonline(_diskfile(bt))
    isnothing(_disk_batch) && return
    doempty && empty!(bt)
    for dat in _disk_batch
        tbl = LiteTapeRecord(bt, dat)
        LiteRecords._lite_push!(bt, tbl)
    end
end

function _ondemand_hardload_diskdepot!(bt::LiteTapeRecord)
    println("_ondemand_hardload_diskdepot!")
    # check demand
    isempty(bt) || return
    # load disk
    _hardload_diskdepot!(bt, false)
end