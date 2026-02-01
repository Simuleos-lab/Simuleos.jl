#TODO: check https://docs.julialang.org/en/v1/base/collections/#Dictionaries for cool Dictlike datatypes

## .-- . -. - .--..- -- .- - --..-.-.- .- -.--
# IDEA: dev ContextDB interface in another package
# - It can run on top of Bloberia

## .-- . -. - .--..- -- .- - --..-.-.- .- -.--
# depot types

# TODO: Narrow types

const UUIDS_DEPOT_TYPE = Set{UInt128}
const DICT_DEPOT_TYPE = Dict{Any, Any}
const VECDICT_DEPOT_TYPE = Dict{Any, Any}

const bUUIDS_FRAMEID = "buuids"

const META_FRAMEID = "meta"

const FRAMES_DEPOT_TYPE = Dict{Any, Any}

## .-- . -. - .--..- -- .- - --..-.-.- .- -.--
# An indexable object to interact with data
# Node in the blobtree
abstract type AbstractBlob end

## .-- . -. - .--..- -- .- - --..-.-.- .- -.--
# TODO: copy pkg README into Bloberia folder

# Top level object
struct Bloberia <: AbstractBlob
    root::String                 # root folder
    frames::FRAMES_DEPOT_TYPE    # ram/disk frame
    temp::DICT_DEPOT_TYPE        # ram only frame
end

## .-- . -. - .--..- -- .- - --..-.-.- .- -.--
# BlobBatch
# #TODO: Add layout comment (see _DEPRECATED)
# =================
# Disk/Data layout
# B (Bloberia)
# ...
struct BlobBatch <: AbstractBlob
    B::Bloberia                  # Parent folder
    id::String
    root::String
    frames::FRAMES_DEPOT_TYPE    # ram/disk frame
    temp::DICT_DEPOT_TYPE        # ram only # TODO/TAI: make Union{Nothing, Dict...}
end

## .-- . -. - .--..- -- .- - --..-.-.- .- -.--
# This is an object defined across different bframes
struct bBlob <: AbstractBlob
    bb::BlobBatch          # owner batch
    uuid::UInt128          # unique universal id
    function bBlob(bb, uuid)
        new(bb, UInt128(uuid))
    end
end

## --.--. - .-. .- .--.-.- .- .---- ... . .-.-.-.- 
struct BlobyRef{lT, rT} 
    link::Dict{String, Any}  # All coordinates   
    BlobyRef(ltype::Symbol, rtype::DataType) = new{ltype, rtype}(Dict())
end

## --.--. - .-. .- .--.-.- .- .---- ... . .-.-.-.- 
# allow ref rolling
struct RefCacher
    depot_cache::Dict{UInt, AbstractBlob}   # path => bb
end

# ## --.--. - .-. .- .--.-.- .- .---- ... . .-.-.-.- 
# nothing