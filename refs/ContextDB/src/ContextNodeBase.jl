## -.--.-.-.- .. .. . . .- --- -- - -- -- .. 
# MARK: SimuleosContextDB index interface

# Path resolution mechanism
# This way we have acces to other further actions as deleting...
# _resolve_path_I(cn::ContextNode, path...) -> container, key

# Note: only allow the p0, ps... if key is at the end
# Otherwise justa dd a single argument

# What is a path
# - It is poliformic

# Fallback to Base.Dict interface
function _resolve_path_I(cn::ContextNode, path::String)
    return cn.depot, path
end

function _resolve_path_I(cn::ContextNode, path::Vector)
    return cn.depot, path
end

# IDEAS
# A register of path resolvers hooks
# - The first on find something returns
# - #TODO/TAI Think about ambiguities
# IDXPATH_RELVERS = Vector{Function}[]

## -.--.-.-.- .. .. . . .- --- -- - -- -- .. 
# MARK: path dependent Base
# Rerut Base.getindex and Base.setindex!

# Note:
# Base.getindex must find a value or return an error
# For any subset filtering/collecting use other interface
import Base.getindex
function Base.getindex(cn::ContextNode, p0, ps...) 
    depot, key = _resolve_path_I(cn, p0, ps...)
    return getindex(depot, key)
end

import Base.setindex!
function Base.setindex!(cn::ContextNode, value, p0, ps...)
    depot, key = _resolve_path_I(cn, p0, ps...)
    setindex!(depot, value, key)
end

function Base.get(cn::ContextNode, path, default) 
    depot, key = _resolve_path_I(cn, path)
    return get(depot, key, default)
end
function Base.get(f::Function, cn::ContextNode, p0, ps...) 
    depot, key = _resolve_path_I(cn, p0, ps...)
    return get(f, depot, key)
end

function Base.get!(cn::ContextNode, path, default) 
    depot, key = _resolve_path_I(cn, path)
    get!(depot, key, default)
end
function Base.get!(f::Function, cn::ContextNode, p0, ps...) 
    depot, key = _resolve_path_I(cn, p0, ps...)
    get!(f, depot, key)
end


function Base.haskey(cn::ContextNode, p0, ps...) 
    depot, key = _resolve_path_I(cn, p0, ps...)
    haskey(depot, key)
end

function Base.delete!(cn::ContextNode, p0, ps...)
    depot, key = _resolve_path_I(cn, p0, ps...)
    delete!(depot, key)
end

## -.--.-.-.- .. .. . . .- --- -- - -- -- .. 
# MARK: path independent  Base
Base.length(cn::ContextNode) = length(cn.depot)
Base.keys(cn::ContextNode) = keys(cn.depot)
Base.values(cn::ContextNode) = values(cn.depot)
Base.iterate(cn::ContextNode, state...) = iterate(cn.depot, state...)
Base.pairs(cn::ContextNode) = pairs(cn.depot)

Base.copy(cn::ContextNode) = ContextNode(Base.copy(cn.depot))