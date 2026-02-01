
# 
module ScopeTapes

    using MassExport
    using Dates
    using JSON
    using SimpleLockFiles
    using OrderedCollections
    using SHA
    using JLD2
    using Serialization
    using StyledStrings

    #! include .
    
    #! include Base
    include("Base/0.types.jl")
    include("Base/1.globals.jl")
    include("Base/99.utils.jl")
    include("Base/ScopeBase.jl")
    include("Base/ScopeVariableBase.jl")
    include("Base/st_blob_hash.jl")
    include("Base/st_blobs.jl")
    include("Base/st_config.jl")
    include("Base/st_disk.jl")
    include("Base/st_init.jl")
    include("Base/st_manifest.jl")
    include("Base/st_scope.jl")
    
    #! include Record
    include("Record/st_commit.jl")
    include("Record/st_hooks.jl")
    include("Record/st_label.jl")
    include("Record/st_write.jl")
    include("Record/static-analysis.jl")
    
    #! include Read
    include("Read/st_foreach_scope.jl")

    @exportall_words()

end