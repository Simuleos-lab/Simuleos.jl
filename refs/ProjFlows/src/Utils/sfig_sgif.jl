# _sfig(x...; k...) = isdefined(ProjFlows, :ImgTools) ? 
#     ImgTools.sfig(x...; k...) : error("You must 'import ImgTools'")
# _sgif(x...; k...) = isdefined(ProjFlows, :ImgTools) ? 
#     ImgTools.sgif(x...; k...) : error("You must 'import ImgTools'")
# _lfig(x...) = isdefined(ProjFlows, :ImgTools) ? 
#     ImgTools.lfig(x...) : error("You must 'import ImgTools'")


# lfig(x...) = _lfig(x...)

# function sfig(p, arg, args...; 
#         print_fun::Function = Base.println, 
#         mkdir = true, 
#         verbose = false,
#         msg::AbstractString = "",
#         kwargs...
#     )

#     datfile = dfname(arg, args...)
#     mkdir && mkpath(dirname(datfile))
#     ret = _sfig(p, datfile; kwargs...)
#     verbose && print_fun("FIGURE SAVED", 
#         isempty(msg) ? "" : string("\n", msg),
#         "\ndir: ", relpath(dirname(abspath(datfile))),
#         "\nfile: ", basename(datfile),
#         "\nsize: ", filesize(datfile), " bytes",
#         "\n"
#     )
#     ret
# end

# function sgif(p, arg, args...; 
#         print_fun::Function = Base.println, 
#         mkdir = true, 
#         verbose = false,
#         msg::AbstractString = "",
#         kwargs...
#     )
#     datfile = dfname(arg, args...)
#     mkdir && mkpath(dirname(datfile))
#     ret = _sgif(p, datfile; kwargs...)
#     verbose && print_fun("GIF SAVED", 
#         isempty(msg) ? "" : string("\n", msg),
#         "\ndir: ", relpath(dirname(abspath(datfile))),
#         "\nfile: ", basename(datfile),
#         "\nsize: ", filesize(datfile), " bytes",
#         "\n"
#     )
#     ret
# end