abstract type AbstractFileRef end

# always load
struct FileRef{T} <: AbstractFileRef
    file::String
end

# load and hold the data
struct FileData{T}  <: AbstractFileRef
    file::String
    cache::Vector{T}
end

