const _GLOBALS_EXT = ".global.jls"

function globfile(Proj::Module, gid::Symbol, gids::Symbol...)
    gids = string.([gid, gids...])
    datdir(Proj, join(gids, "."), _GLOBALS_EXT)
end

function lglob(Proj::Module, gid::Symbol, gids::Symbol...)
    fname = globfile(Proj, gid, gids...)
    !isfile(fname) && error("global is missing, glob file '", basename(fname), "' not found")
    return ldat(fname; verbose = false)
end

function lglob(Proj::Module, gidv::Vector) 
    map(gidv) do arg
        (arg isa Symbol) ? lglob(Proj, arg) : lglob(Proj, arg...)
    end
end

macro lglob(Proj::Symbol, ex, exs...)
    _lglob_macro_ex(Proj, ex, exs...)
end

macro lglob(ex, exs...)
    error("You must specify a project module Ex: `Proj gid`")
end

## ------------------------------------------------------------
function sglob(Proj::Module, dat, gid::Symbol, gids::Symbol...)
    fname = globfile(Proj, gid, gids...)
    sdat(Proj, dat, fname; verbose = false)
end

function sglob(Proj::Module; gids...)
    for (gid, dat) in gids
        sglob(Proj, dat, gid)
    end
end

sglob(f::Function, Proj::Module, gid::Symbol, gids::Symbol...) = sglob(Proj, f(), gid, gids...)

macro sglob(Proj::Symbol, ex, exs...)
    _sglob_macro_ex(Proj, ex, exs...)
end

macro sglob(ex, exs...)
    error("You must specify a project module Ex: `Proj gid=dat`")
end

## ------------------------------------------------------------
delglob(Proj::Module, gid::Symbol, gids::Symbol...) = rm(globfile(Proj, gid, gids...); force = true)