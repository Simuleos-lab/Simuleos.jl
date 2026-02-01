# LiteTapeRecord
# - one single entry point to disk
#   - create -> push!(batch, blob) -> commit!(batch)
# - load data on demand, no at obj construction
# - uses

# Load from disk only if depot is empty
# - at data request, eg: getindex(blob, "A")
#   - or an explicit diskload!(blob)
# - this will overwrite
# - have a copy version too
#    - diskcopy(blob) -> Dict
#       - a new copy of the disk
#    - Useful for mergins

# No random access at base level
# later, an index can be implemented
# the batch is think to be iterated serialy
# it is an array

# Data in one place 
# better reload that have duplications on runtime
# objects are just views

function LiteTapeRecord(
        parent::LiteTapeSegment, 
        objkey = string(uuid4())
    )
    
    bl = LiteTapeRecord(parent, LiteRecord())

    # process __literecord_meta__
    mt = __literecord_meta__!(bl)
    mt["objkey"] = objkey

    return bl
end
