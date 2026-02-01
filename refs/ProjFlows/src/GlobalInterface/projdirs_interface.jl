# implement the methods for getting tree structures

# To implement
# - projpath
#   - the root path 
# - dotprojflow_dir

dotprojflow_dir() = dotprojflow_dir(globproj())

function projpath(args...) 
    fn1 = dfname(args...)
    isabspath(fn1) && return fn1
    return dfname([projpath(globproj())], args...)
end