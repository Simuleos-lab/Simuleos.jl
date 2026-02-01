# implement the methods for getting tree structures

# To implement
# - projpath
#   - the root path 
# - dotprojflow_dir

dotprojflow_dir(p::AbstractProject) = joinpath(projpath(p), ".projflow")

projpath(P::AbstractProject, args...) = dfname([projpath(P)], args...)