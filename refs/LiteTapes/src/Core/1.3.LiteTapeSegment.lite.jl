## .- .- .. . .. . - - -  - . - .. --. .- -..- -
# MARK: lite interface
# Overwrite base methods to include disk handling

import LiteRecords.lite_push!
function LiteRecords.lite_push!(tb::LiteTapeSegment, bl::LiteTapeRecord)
    _ondemand_hardload_diskdepot!(tb)
    # call Abstract base LiteRecords
    LiteRecords._lite_push!(tb, bl)
end

import LiteRecords.lite_getindex
function lite_getindex(tb::LiteTapeSegment, k, ks...)
    _ondemand_hardload_diskdepot!(tb)
    # call Abstract base LiteRecords
    LiteRecords._lite_getindex(tb, k, ks...)
end

function lite_setindex!(tb::LiteTapeSegment, bl::LiteTapeSegment, k, ks...)
    _ondemand_hardload_diskdepot!(tb)
    # call Abstract base LiteRecords
    LiteRecords._lite_setindex!(tb, bl, k, ks...)
end