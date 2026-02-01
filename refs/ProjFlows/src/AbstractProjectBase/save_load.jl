# ## ---------------------------------------------------------------------
# # save data
# function sdat(f::Function, Proj::AbstractProject, dfarg, dfargs...; sdatkwargs...)
#     file = datdir(Proj, dfarg, dfargs...)
#     sdat(f, file; sdatkwargs...)
# end

# function sdat(Proj::AbstractProject, dat, dfarg, dfargs...; sdatkwargs...)
#     file = datdir(Proj, dfarg, dfargs...)
#     sdat(dat, file; sdatkwargs...)
# end

# ## ---------------------------------------------------------------------
# # load data
# function ldat(f::Function, Proj::AbstractProject, dfarg, dfargs...; ldatkwargs...)
#     datfile = datdir(Proj, dfarg, dfargs...)
#     ldat(f, datfile; ldatkwargs...)
# end

# function ldat(Proj::AbstractProject, dfarg, dfargs...; ldatkwargs...)
#     datfile = datdir(Proj, dfarg, dfargs...)
#     ldat(datfile; ldatkwargs...)
# end

# ## ---------------------------------------------------------------------
# # withdat
# function withdat(f::Function, Proj::AbstractProject, mode::Symbol, dfarg, dfargs...; kwargs...)
#     datfile = datdir(Proj, dfarg, dfargs...)
#     return withdat(f, mode, datfile; kwargs...)
# end

# withdat(Proj::AbstractProject, dat::Any, mode::Symbol, dfarg, dfargs...; kwargs...) = 
#     withdat(() -> dat, Proj, mode, dfarg, dfargs...; kwargs...)


# ## ---------------------------------------------------------------------
# # save/load fig
# sfig(Proj::AbstractProject, p, arg, args...; kwargs...) = sfig(p, plotsdir(Proj, arg, args...); kwargs...)
# sfig(f::Function, Proj::AbstractProject, arg, args...; kwargs...) = sfig(Proj, f(), arg, args...; kwargs...)

# sgif(Proj::AbstractProject, p, arg, args...; kwargs...) = sgif(p, plotsdir(Proj, arg, args...); kwargs...)
# sgif(f::Function, Proj::AbstractProject, arg, args...; kwargs...) = sgif(Proj, f(), arg, args...; kwargs...)