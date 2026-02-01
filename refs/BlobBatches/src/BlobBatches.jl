# TODO: add folder size control: Once folder_size > limit, no more serializing (error)
# TDOD: add read only features

module BlobBatches

    using Serialization
    using SimpleLockFiles
    using OrderedCollections
    using Base.Threads

    export BlobBatch
    export deserialize, deserialize!, serialize
    export hasframe, unloadframe!, loadallframe!, loadframe!, isframeloaded
    export hasfilesys, rootdir, rootdir!, framefile
    export test_blobdb
    
    #! include .
    
    #! include 0_Types
    include("0_Types/BlobBatch.jl")
    
    #! include BlobBatchBase
    include("BlobBatchBase/base.jl")
    include("BlobBatchBase/filesys.jl")
    include("BlobBatchBase/frames.jl")
    include("BlobBatchBase/lock.jl")
    include("BlobBatchBase/serialization.jl")
    include("BlobBatchBase/testdb.jl")
    include("BlobBatchBase/utils.jl")
    include("BlobBatchBase/walkdir.jl")
end