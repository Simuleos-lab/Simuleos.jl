# ## ---------------------------------------------------------------------
# # save data
# srawdat(f::Function, Proj::Project0, dfarg, dfargs...; sdatkwargs...) = 
#     sdat(f, Proj, ["raw"], dfarg, dfargs...; sdatkwargs...) 
# srawdat(Proj::Project0, dat, dfarg, dfargs...; sdatkwargs...) = 
#     sdat(Proj, dat, ["raw"], dfarg, dfargs...; sdatkwargs...)

# sprocdat(f::Function, Proj::Project0, dfarg, dfargs...; sdatkwargs...) = 
#     sdat(f, Proj, ["processed"], dfarg, dfargs...; sdatkwargs...) 
# sprocdat(Proj::Project0, dat, dfarg, dfargs...; sdatkwargs...) = 
#     sdat(Proj, dat, ["processed"], dfarg, dfargs...; sdatkwargs...)

# ## ---------------------------------------------------------------------
# # load data
# lrawdat(Proj::Project0, dfarg, dfargs...; ldatkwargs...) = 
#     ldat(Proj, ["raw"], dfarg, dfargs...; ldatkwargs...)
# lrawdat(f::Function, Proj::Project0, dfarg, dfargs...; ldatkwargs...) = 
#     ldat(f, Proj, ["raw"], dfarg, dfargs...; ldatkwargs...)

# lprocdat(Proj::Project0, dfarg, dfargs...; ldatkwargs...) = 
#     ldat(Proj, ["processed"], dfarg, dfargs...; ldatkwargs...)
# lprocdat(f::Function, Proj::Project0, dfarg, dfargs...; ldatkwargs...) = 
#     ldat(f, Proj, ["processed"], dfarg, dfargs...; ldatkwargs...)

# ## ---------------------------------------------------------------------
# # withdat
# withrawdat(f::Function, Proj::Project0, mode::Symbol, dfarg, dfargs...; kwargs...) =
#     withdat(f, Proj, mode, ["raw"], dfarg, dfargs...; kwargs...)
# withrawdat(Proj::Project0, dat::Any, mode::Symbol, dfarg, dfargs...; kwargs...) = 
#     withrawdat(() -> dat, Proj, mode, dfarg, dfargs...; kwargs...)

# withprocdat(f::Function, Proj::Project0, mode::Symbol, dfarg, dfargs...; kwargs...) = 
#     withdat(f, Proj, mode, ["processed"], dfarg, dfargs...; kwargs...)
# withprocdat(Proj::Project0, dat::Any, mode::Symbol, dfarg, dfargs...; kwargs...) = 
#     withprocdat(() -> dat, Proj, mode, dfarg, dfargs...; kwargs...)


# ## ---------------------------------------------------------------------
# # cache 

# lcachedat(Proj::Project0, dfarg, dfargs...; ldatkwargs...) = 
#     ldat(Proj, ["cache"], dfarg, dfargs...; ldatkwargs...)
# lcachedat(f::Function, Proj::Project0, dfarg, dfargs...; ldatkwargs...) = 
#     ldat(f, Proj, ["cache"], dfarg, dfargs...; ldatkwargs...)

# scachedat(Proj::Project0, dat, dfarg, dfargs...; sdatkwargs...) = 
#     sdat(Proj, dat, ["cache"], dfarg, dfargs...; sdatkwargs...)
# scachedat(f::Function, Proj::Project0, dfarg, dfargs...; sdatkwargs...) = 
#     sdat(f, Proj, ["cache"], dfarg, dfargs...; sdatkwargs...) 

# withcachedat(f::Function, Proj::Project0, mode::Symbol, dfarg, dfargs...; kwargs...) = 
#     withdat(f, Proj, mode, ["cache"], dfarg, dfargs...; kwargs...)
# withcachedat(Proj::Project0, dat::Any, mode::Symbol, dfarg, dfargs...; kwargs...) = 
#     withcachedat(() -> dat, Proj, mode, dfarg, dfargs...; kwargs...)

# function cache_hashfile(Proj::Project0, arg::Tuple)
#     _hash = hash(hash.(arg))
#     cachedir(Proj, (;hash = _hash), ".cache.jls")
# end

# lcachedat(Proj::Project0, dfarg::Tuple; ldatkwargs...) = 
#     ldat(cache_hashfile(Proj, dfarg); ldatkwargs...)
# lcachedat(f::Function, Proj::Project0, dfarg::Tuple; ldatkwargs...) = 
#     ldat(f, cache_hashfile(Proj, dfarg); ldatkwargs...)

# scachedat(f::Function, Proj::Project0, dfarg::Tuple; ldatkwargs...) = 
#     sdat(f, cache_hashfile(Proj, dfarg); ldatkwargs...)
# scachedat(Proj::Project0, dat,dfarg::Tuple; ldatkwargs...) = 
#     sdat(dat, cache_hashfile(Proj, dfarg); ldatkwargs...)

# withcachedat(f::Function, Proj::Project0, mode::Symbol, dfarg::Tuple; kwargs...) = 
#     withdat(f, mode, cache_hashfile(Proj, dfarg); kwargs...)
# withcachedat(Proj::Project0, dat::Any, mode::Symbol, dfarg::Tuple; kwargs...) = 
#     withdat(dat, mode, cache_hashfile(Proj, dfarg); kwargs...)

