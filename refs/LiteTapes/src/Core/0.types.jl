# abstract type AbstractLiteTapeSegment <: AbstractLiteRecordArray end
# abstract type AbstractLiteTapeRecord <: AbstractLiteRecord end

# Just the root of the tapeTree
# It contain more tapes folders
struct LiteTapeLib <: AbstractLiteObj
    path::String
    __extras__::Dict{String, Any}
end

# The root of a tape
# - #TAI should be dataless
struct LiteTape <: AbstractLiteObj
    path::String
    #TODO Finish to implement
end

# The tape is stored on batched of blobs
# - This is conveniant for efficient loading
struct LiteTapeSegment{T<:AbstractLiteRecord} <: AbstractLiteRecordArray
    parent::LiteTapeLib
    path::String
    depot::LiteRecordArray{T}   # raw data
end

# A wrapper of the blob::Dict data
# - I can them dispatch to the Tapes interfaces
struct LiteTapeRecord <: AbstractLiteRecord
    parent::LiteTapeSegment
    depot::LiteRecord      # raw data
end

# Be close to data
# - All this objects are cheap wrapers
# - The data is stored raw
# - the wrapers are created on demand
# - you can collect them yourself if convenient

