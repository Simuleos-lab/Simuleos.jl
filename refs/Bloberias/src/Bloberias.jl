

module Bloberias

    import Serialization
    
    using MassExport
    using OrderedCollections
    using Dates
    using Serialization
    using UUIDs
    using Base.Threads
    using SimpleLockFiles

    #! include .

    #! include 0.Base
    include("0.Base/0_types.jl")
    include("0.Base/kv_interface.jl")
    include("0.Base/utils.jl")
    
    #! include 1.AbstractBlobBase
    include("1.AbstractBlobBase/base.jl")
    include("1.AbstractBlobBase/callbacks.jl")
    include("1.AbstractBlobBase/lock.jl")
    include("1.AbstractBlobBase/show.jl")
    include("1.AbstractBlobBase/tree.depot.jl")
    include("1.AbstractBlobBase/tree.depotdisk.jl")
    include("1.AbstractBlobBase/tree.disk.jl")
    include("1.AbstractBlobBase/tree.pub.jl")

    #! include 2.BloberiaBase
    include("2.BloberiaBase/base.jl")
    include("2.BloberiaBase/blobbatch.jl")
    include("2.BloberiaBase/iterator.jl")
    include("2.BloberiaBase/show.jl")
    include("2.BloberiaBase/tree.interface.jl")
    
    #! include 3.BlobBatchBase
    include("3.BlobBatchBase/base.jl")
    include("3.BlobBatchBase/blob.jl")
    include("3.BlobBatchBase/iterator.jl")
    include("3.BlobBatchBase/show.jl")
    include("3.BlobBatchBase/tree.interface.jl")
    
    #! include 4.bBlobBase
    include("4.bBlobBase/base.jl")
    include("4.bBlobBase/show.jl")
    include("4.bBlobBase/tree.interface.jl")

    #! include 5.BlobyRefBase
    include("5.BlobyRefBase/base.jl")
    include("5.BlobyRefBase/deref.jl")
    include("5.BlobyRefBase/ref.jl")
    include("5.BlobyRefBase/tree.interface.jl")

    #! include 6.RefCacher
    include("6.RefCacher/base.jl")
    include("6.RefCacher/deref.jl")
    include("6.RefCacher/tree.interface.jl")

    @exportall_words()

end