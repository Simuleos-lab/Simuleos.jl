# The default project layout
struct Project0 <: AbstractProject
    root::String
    extras::Dict
    Project0(root::AbstractString) = new(root, Dict())
end

# From module
function Project0(m::Module) 
    dir = pkgdir(m)
    isnothing(dir) && error("module '", m, "' has no directory!")
    return Project0(dir)
end

