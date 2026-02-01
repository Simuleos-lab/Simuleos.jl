# Core types
# TODO: Add type parameters
abstract type AbstractLiteObj end
abstract type AbstractLiteRecord <: AbstractLiteObj end
abstract type AbstractLiteRecordArray <: AbstractLiteObj end

# A dict like struct
struct LiteRecord <: AbstractLiteRecord
    # primary storage (Lite "standard")
    __depot__::OrderedDict{String,Any}

    # runtime-only extras
    # - for instance, for implementing a dynamic struct
    __extras__::Dict{String,Any}
end

LiteRecord() = LiteRecord(OrderedDict(), Dict())

# A vector of LiteRecords
struct LiteRecordArray{T<:AbstractLiteRecord} <: AbstractLiteRecordArray
    __depot__::Vector{T}
    __extras__::Dict{String,Any}
end

# Convenience: allow construction from just a vector
function LiteRecordArray(
    depot::Vector{T}
) where {T<:AbstractLiteRecord}
    LiteRecordArray{T}(depot, Dict())
end

LiteRecordArray{T}() where {T<:AbstractLiteRecord} = 
    LiteRecordArray(Vector{T}())