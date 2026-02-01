import Base.show 
show(io::IO, p::AbstractProject) = println(
    io, typeof(p), "\n", 
    "root: ", projpath(p)
)