_sfig(x...; k...) = isdefined(ProjAssistant, :ImgTools) ? 
    ImgTools.sfig(x...; k...) : error("You must 'import Plots'")
_sgif(x...; k...) = isdefined(ProjAssistant, :ImgTools) ? 
    ImgTools.sgif(x...; k...) : error("You must 'import Plots'")
_lfig(x...) = isdefined(ProjAssistant, :ImgTools) ? 
    ImgTools.lfig(x...) : error("You must 'import Plots'")


lfig(x...) = _lfig(x...)

function sfig(p, arg, args...; 
        print_fun::Function = global_conf(:PRINT_FUN), 
        mkdir = global_conf(:MK_DIR), 
        verbose = global_conf(:VERBOSE),
        msg::AbstractString = "",
        kwargs...
    )

    datfile = dfname(arg, args...)
    mkdir && mkpath(dirname(datfile))
    ret = _sfig(p, datfile; kwargs...)
    verbose && print_fun("FIGURE SAVED", 
        isempty(msg) ? "" : string("\n", msg),
        "\ndir: ", relpath(dirname(abspath(datfile))),
        "\nfile: ", basename(datfile),
        "\nsize: ", filesize(datfile), " bytes",
        "\n"
    )
    ret
end

function sgif(p, arg, args...; 
        print_fun::Function = global_conf(:PRINT_FUN), 
        mkdir = global_conf(:MK_DIR), 
        verbose = global_conf(:VERBOSE),
        msg::AbstractString = "",
        kwargs...
    )
    datfile = dfname(arg, args...)
    mkdir && mkpath(dirname(datfile))
    ret = _sgif(p, datfile; kwargs...)
    verbose && print_fun("GIF SAVED", 
        isempty(msg) ? "" : string("\n", msg),
        "\ndir: ", relpath(dirname(abspath(datfile))),
        "\nfile: ", basename(datfile),
        "\nsize: ", filesize(datfile), " bytes",
        "\n"
    )
    ret
end