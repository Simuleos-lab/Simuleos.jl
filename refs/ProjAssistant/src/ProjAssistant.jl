module ProjAssistant

    import DrWatson
    import Logging
    import Logging: SimpleLogger, global_logger, with_logger
    import Serialization: serialize, deserialize
    import FileIO
    import Requires: @require
    import Pkg
    using FilesTreeTools
    using ExtractMacro
    using Base.Threads
    using DataFileNames

    include("utils.jl")
    include("_io_print.jl")
    include("io_global_conf.jl")
    include("_save_load.jl")
    include("scache_lcache.jl")
    include("sdat_ldat.jl")
    include("group_files.jl")
    include("gen_sub_proj.jl")
    include("gen_top_proj.jl")
    include("create_proj_dirs.jl")
    include("sfig_sgif.jl")
    include("sglob_lglob_macros_ex.jl")
    include("sglob_lglob.jl")
    include("proj_functions.jl")
    include("fileid.jl")
    include("quickactivate.jl")

    export parentproj, topproj, istop_proj
    export projdir, projname, set_projdir
    export devdir, datdir, srcdir, plotsdir, scriptsdir, papersdir
    export cachedir, procdir, rawdir
    export lsdevdir, lsdatdir, lssrcdir, lsplotsdir, lsscriptsdir,
           lspapersdir, lsprocdir, lsrawdir, lscachedir
    export sdat, sprocdat, srawdat, sfig, sgif
    export ldat, lprocdat, lrawdat, lfig
    export cfname, is_cfname, scache, lcache, delcache
    export globfile, sglob, lglob, delglob, @lglob, @sglob
    export gen_top_proj, @gen_top_proj
    export gen_sub_proj, @gen_sub_proj
    export create_proj_dirs, @create_proj_dirs
    export @fileid
    export quickactivate, @quickactivate

    # Re-exports
    export dfname, parse_dfname
    export @extract
    export walkdown, filtertree

    function __init__()
        _init_globals()

        @require Plots = "91a5bcdd-55d7-5caf-9e0b-520d859cae80" begin
            import ImgTools
        end
    end

end
