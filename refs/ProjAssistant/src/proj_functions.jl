## ------------------------------------------------------------
# utils 
_is_proj(Proj::Module) = isdefined(Proj, :_PROJ_ASSIST_CONF)
_check_is_proj(Proj::Module) = !_is_proj(Proj) && error("Module ", nameof(Proj), 
    " is not a ProjAssistant project. See `gen_sub_proj` or `gen_top_proj`"
)

## ---------------------------------------------------------------------
# top funs
parentproj(Proj::Module) = (_check_is_proj(Proj); Proj._PROJ_ASSIST_CONF[:PARENT_PROJ])
topproj(Proj::Module) = (_check_is_proj(Proj); Proj._PROJ_ASSIST_CONF[:TOP_PROJ])
projname(Proj::Module) = string(nameof(Proj))
istop_proj(Proj::Module) = (parentproj(Proj) === Proj)

## ---------------------------------------------------------------------
# top folders
set_projdir(Proj::Module, dir::AbstractString) = 
    (topproj(Proj)._PROJ_ASSIST_CONF[:ROOT_DIR] = dir)
projdir(Proj::Module) = topproj(Proj)._PROJ_ASSIST_CONF[:ROOT_DIR]
projdir(Proj::Module, dfargs...) = dfname([projdir(Proj)], dfargs...)

for (funname, dirname) = [
        (:devdir, "dev"),
        (:srcdir, "src"), (:plotsdir, "plots"),
        (:scriptsdir, "scripts"), (:papersdir, "papers"),
    ]

    @eval begin
        function $(funname)(Proj::Module, dfargs...)
            rootdir = istop_proj(Proj) ? 
                projdir(Proj, [$(dirname)]) :
                $(funname)(parentproj(Proj), [projname(Proj)])
            dfname([rootdir], dfargs...)
        end
    end
end

function datdir(Proj::Module, dfargs...)
    rootdir = istop_proj(Proj) ? 
        projdir(Proj, ["data"]) : 
        procdir(Proj)
    dfname([rootdir], dfargs...)
end

## ---------------------------------------------------------------------
# sub data folders
for (funname, dirname) = [
        (:procdir, "processed"), (:rawdir, "raw"),
    ]
    @eval begin
        function $(funname)(Proj::Module, dfargs...)
            rootdir = istop_proj(Proj) ? 
                datdir(Proj, [$(dirname)]) :
                $(funname)(parentproj(Proj), [projname(Proj)])
            dfname([rootdir], dfargs...)
        end 
    end
end

function cachedir(Proj, dfargs...)
    rootdir = istop_proj(Proj) ? 
        datdir(Proj, ["cache"]) :
        cachedir(parentproj(Proj), [projname(Proj)])
    dir, dfargs = _extract_dir(dfargs...)
    rootdir = isempty(dir) ? rootdir : joinpath(rootdir, dir)
    return isempty(dfargs) ? rootdir : joinpath(rootdir, cfname(dfargs...))
end

## ---------------------------------------------------------------------
# ls funs
for funname in [
    :devdir, :datdir, :srcdir, :plotsdir, :scriptsdir, :papersdir, 
    :procdir, :rawdir, :cachedir
]
    lsfun = Symbol(:ls, funname)
    @eval begin 
        function $(lsfun)(Proj::Module, args...)
            dir = $(funname)(Proj, args...)
            fs = readdir(dir)
            println(join(fs, "\n"))
        end
    end
end

## ---------------------------------------------------------------------
# save data
for (sfun, filefun) in [
        (:sdat, :procdir), 
        (:sprocdat, :procdir), 
        (:srawdat, :rawdir)
    ]
    @eval begin
        function $(sfun)(f::Function, Proj::Module, dfarg, dfargs...; sdatkwargs...)
            file = $(filefun)(Proj, dfarg, dfargs...)
            sdat(f, file; sdatkwargs...)
        end

        function $(sfun)(Proj::Module, dat, dfarg, dfargs...; sdatkwargs...)
            file = $(filefun)(Proj, dfarg, dfargs...)
            sdat(dat, file; sdatkwargs...)
        end
    end
end

## ---------------------------------------------------------------------
# load data
for (lfun, filefun) in [
        (:ldat, :procdir), 
        (:lprocdat, :procdir), 
        (:lrawdat, :rawdir)
    ]
    @eval begin
        function $(lfun)(f::Function, Proj::Module, dfarg, dfargs...; sdatkwargs...)
            file = $(filefun)(Proj, dfarg, dfargs...)
            ldat(f, file; sdatkwargs...)
        end

        function $(lfun)(Proj::Module, dfarg, dfargs...; sdatkwargs...)
            file = $(filefun)(Proj, dfarg, dfargs...)
            ldat(file; sdatkwargs...)
        end
    end
end

## ---------------------------------------------------------------------
# save/load fig
sfig(Proj::Module, p, arg, args...; kwargs...) = sfig(p, plotsdir(Proj, arg, args...); kwargs...)
sfig(f::Function, Proj::Module, arg, args...; kwargs...) = sfig(Proj, f(), arg, args...; kwargs...)
sgif(Proj::Module, p, arg, args...; kwargs...) = sgif(p, plotsdir(Proj, arg, args...); kwargs...)
sgif(f::Function, Proj::Module, arg, args...; kwargs...) = sgif(Proj, f(), arg, args...; kwargs...)
    
## ---------------------------------------------------------------------
# save/load cache
scache(Proj::Module, dat, args...; kwargs...) = 
    scache(dat, [cachedir(Proj)], args...; kwargs...)
scache(f::Function, Proj::Module, args...; kwargs...) = 
    scache(Proj, f(), args...; kwargs...)

lcache(Proj::Module, args...; kwargs...) = 
    lcache([cachedir(Proj)], args...; kwargs...)
lcache(f::Function, Proj::Module, args...; kwargs...) = 
    lcache(f, [cachedir(Proj)], args...; kwargs...)

delcache(Proj::Module, args...; kwargs...) = delcache([cachedir(Proj)], args...; kwargs...)
