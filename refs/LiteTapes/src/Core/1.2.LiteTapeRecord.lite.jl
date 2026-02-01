## .- .- .. . .. . - - -  - . - .. --. .- -..- -
# MARK: lite interface
# Overwrite base methods to include disk handling

import LiteRecords.lite_push!
function LiteRecords.lite_push!(bl::LiteTapeRecord, val::Any)
    _ondemand_hardload_diskdepot!(bl)
    # call Abstract base LiteRecords
    LiteRecords._lite_push!(bl, val)
end

import LiteRecords.lite_getindex
function lite_getindex(bl::LiteTapeRecord, k, ks...)
    _ondemand_hardload_diskdepot!(bl)
    # call Abstract base LiteRecords
    LiteRecords._lite_getindex(bl, k, ks...)
end

function lite_setindex!(bl::LiteTapeRecord, val::Any, k, ks...)
    _ondemand_hardload_diskdepot!(bl)
    # call Abstract base LiteRecords
    LiteRecords._lite_setindex!(bl, val, k, ks...)
end