# TODO: Think on a WIP feature

# DONE: Add optional tags to cache

# TODO?: Integrate ContextDBs

# TODO?: Integrate BlobBatches

# TODO: Integrate LRUCache.jl... Memoize.jl... DataStructures.jl... Just explore github.com/JuliaCollections

# DONE: using Pidfile

# DONE: Add @peeklite... we need a way to merge a dict
# Maybe b[[]] .= @peeklite
# What is wrong with merge!(b[["EP.v1]], @peeklite())?
# mergescope!(b, "EP.v1; filter = :lite)?
# DONE: Multithreading load/do
# DONE: Multithreading search
# DONE: ContextDB-like (pattern based + product Query) search interface


module ProjFlows

    import Logging
    import Logging: SimpleLogger, global_logger, with_logger
    import Serialization: serialize, deserialize
    import FileIO
    import Pkg
    using ExtractMacro
    using Base.Threads
    using FileWatching.Pidfile
    using Reexport
    using Dates
    
    # import ImgTools
    @reexport using SimpleLockFiles
    @reexport using FilesTreeTools
    @reexport using DataFileNames
    @reexport using Bloberias
    @reexport using MassExport

    #! include .
    
    #! include Types
    include("Types/AbtractProjects.jl")
    include("Types/DrWatsonProject.jl")
    include("Types/FileData.jl")
    include("Types/Project0s.jl")
    
    #! include AbstractProjectBase
    include("AbstractProjectBase/base.jl")
    include("AbstractProjectBase/extras_interface.jl")
    include("AbstractProjectBase/lock.jl")
    include("AbstractProjectBase/projdirs_interface.jl")
    include("AbstractProjectBase/save_load.jl")
    
    #! include Utils
    include("Utils/_io_print.jl")
    include("Utils/datio.jl")
    include("Utils/exportall.jl")
    include("Utils/extras_interface.jl")
    include("Utils/fileid.jl")
    include("Utils/group_files.jl")
    include("Utils/lite_interface.jl")
    include("Utils/parseARGS.jl")
    include("Utils/quickactivate.jl")
    include("Utils/scope_interface.jl")
    include("Utils/sdat_ldat.jl")
    include("Utils/sfig_sgif.jl")
    include("Utils/utils.jl")
    # include("Utils/sfig_sgif.jl")

    #! include Project0Base
    include("Project0Base/bloberias.jl")
    include("Project0Base/projdirs_interface.jl")
    include("Project0Base/save_load.jl")
    
    #! include FileDataBase
    include("FileDataBase/base.jl")
    
    #! include GlobalInterface
    include("GlobalInterface/datio.jl")
    include("GlobalInterface/globproj.jl")
    include("GlobalInterface/projdirs_interface.jl")

    @exportall_non_underscore()

    function __init__()
        # TODO: do not load Plot packages if not required (not working now)
        # @require ImgTools = "60a16571-0043-4368-b1b0-a5366d36b020" begin
        #     println("ImgTools")
        #     @eval import ImgTools
        # end
        # @require Plots = "91a5bcdd-55d7-5caf-9e0b-520d859cae80" begin
        #     println("Plots")
        #     @eval import ImgTools
        # end
        # @require CairoMakie = "13f3f980-e62b-5c42-98c6-ff1f3baf88f0" begin
        #     println("CairoMakie")
        #     @eval import ImgTools
        # end
        # @require Makie = "ee78f7c6-11fb-53f2-987a-cfe4a2b5a57a" begin
        #     println("Makie")
        #     @eval import ImgTools
        # end
    end

end