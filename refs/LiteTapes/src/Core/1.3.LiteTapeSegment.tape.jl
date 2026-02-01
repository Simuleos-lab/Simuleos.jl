# DOING
# Question: Do I accept invalid objects?
# - Do I do all at the construction
#   - The basic definatly yes
# - create an <object key> interface
#   - the objecty key is just an unique identifier
#   - unique to each creation of a blob
#   - the user do not control its settings
#   - the objid will be part of the object content
#   - I mean, it is data...
# - later, we can add more identifier for different applications
# - or, hashes
# - Do I accept invalid objects?
#   - I can ignore them on by key search
#   - Maybe create the id only if a link is need it
#       - this will need t modify the object
#   - I can just error
#       - yes, I like it
#       - objkey is at the end just an interface
#       - if you don't comply, you most fix it by yourself.
#           - eg: an explicit call to `objkey_rehash!(blob)`


# Interfaces
# - un recorded
#   - runtime object

# LiteTapeSegment interface
# - new/load interface
#   - newbatch!
#   - loadbatch!
# - consistance naming
#   - force interface
#   - suggest best practice
#   - force on validation (community ignored invalids)
# - single write point
#   - all op. are disk -> ram, or ram -> ram operations
#   - except `commit!` goes ram -> disk
# - load files on obj demand
#

# construct
# if diskless, it is not persistant
# also, it can't be reached from parent
# LiteTapeLib uses filesys as depot
function LiteTapeSegment(
        parent::LiteTapeLib, 
        name::String
    )
    name = replace(name, r"\.jsonl$" => "")
    name = string(name, ".jsonl")
    path = joinpath(parent.path, name)
    bt = LiteTapeSegment(parent, path, LiteRecordArray{LiteTapeRecord}())
    # add extras if required
    return bt
end

LiteTapeSegment(tb::LiteTapeRecord) = tb.parent

## .- .- .. . .. . - - -  - . - .. --. .- -..- -
# MARK: tabe base

# function tape_push!(tb::LiteTapeSegment, bl::LiteTapeRecord)
#     arr = __depot__(tb)
#     lbl =  __depot__(bl)
#     push!(arr, lbl)
# end

# function tape_getindex(tb::LiteTapeSegment, k, ks...)
#     arr = __depot__(tb)
#     lbl = getindex(arr, k, ks...)
#     bl = LiteTapeRecord(tb, lbl)
#     return bl
# end

# function tape_setindex!(tb::LiteTapeSegment, bl::LiteTapeSegment, k, ks...)
#     arr = __depot__(tb)
#     lbl =  __depot__(bl)
#     setindex!(arr, lbl, k, ks...)
# end