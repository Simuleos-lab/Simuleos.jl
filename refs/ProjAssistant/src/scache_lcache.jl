const CFNAME_EXT = ".cache.jls"

## ----------------------------------------------------------------------------
function is_cfname(fname)
    fname = basename(fname)
    !isvalid_dfname(fname) && return false
    head, params, ext = parse_dfname(fname)
    return isempty(head) && length(params) == 1 && 
        haskey(params, "hash") && (ext == CFNAME_EXT)
end

## ----------------------------------------------------------------------------
function _cfname(arg, args...)
    _hash = hash(hash.((arg, args...)))
    dfname((;hash = _hash), CFNAME_EXT)
end

_cfname() = _cfname(threadid(), time(), rand())

cfname() = _cfname()
cfname(str::AbstractString) = is_cfname(str) ? str : _cfname(str)
function cfname(arg, args...)    
    dir, args = _extract_dir(arg, args...)
    return joinpath(dir, _cfname(args...))
end


## ----------------------------------------------------------------------------
function _scache(dat, cfile; 
        onerr::Function = (err) -> rethrow(err), 
        print_fun::Function = global_conf(:PRINT_FUN),
        mkdir::Bool = global_conf(:MK_DIR),
        verbose::Bool = global_conf(:VERBOSE), 
        msg::String = "",
    )
    
    try
        mkdir && mkpath(dirname(cfile))
        serialize(cfile, Dict(DATA_KEY => dat))
        verbose && _io_print(print_fun, "CACHE SAVED", msg, dat, cfile)
    catch err
        verbose && _io_error_print(print_fun, err, cfile)
        onerr(err)
    end
    return cfile
end

# defaults
function scache(dat, dirv::Vector{<:AbstractString}, args...; kwargs...)
    dir, args = _extract_dir(dirv, args...)
    cfile = joinpath(dir, cfname(args...))
    _scache(dat, cfile; kwargs...)
end
scache(dat, args...; kwargs...) = 
    scache(dat, [global_conf(:CACHE_DIR)], args...; kwargs...)
scache(f::Function, args...; kwargs...) = scache(f(), args...; kwargs...)

## ----------------------------------------------------------------------------
function _lcache(f::Function, savecache::Bool, 
        dirv::Vector{<:AbstractString}, arg, args...; 
        onerr::Function = (err) -> rethrow(err),
        print_fun::Function = global_conf(:PRINT_FUN), 
        mkdir::Bool = global_conf(:MK_DIR),
        verbose::Bool = global_conf(:VERBOSE), 
        msg::AbstractString = "",
    )
    
    dir, args = _extract_dir(dirv, arg, args...)
    cfile = joinpath(dir, cfname(args...))
    try
        mkdir && mkpath(dirname(cfile))
        dat = isfile(cfile) ? deserialize(cfile)[DATA_KEY] : f()
        savecache && _scache(dat, cfile; verbose, onerr, print_fun)
        verbose && _io_print(print_fun, "CACHE LOADED", msg, dat, cfile)
        return dat
    catch err
        verbose && _io_error_print(print_fun, err, cfile)
        return onerr(err)
    end
end

lcache(f::Function, dirv::Vector{<:AbstractString}, arg, args...; kwargs...) =
    _lcache(f, true, dirv, arg, args...; kwargs...)

lcache(f::Function, arg, args...; kwargs...) = 
    lcache(f::Function, [global_conf(:CACHE_DIR)], arg, args...; kwargs...)

lcache(dirv::Vector{<:AbstractString}, arg, args...; kwargs...) =
    _lcache(() -> nothing, false, dirv, arg, args...; kwargs...)

lcache(arg, args...; kwargs...) = 
    lcache([global_conf(:CACHE_DIR)], arg, args...; kwargs...)

## ----------------------------------------------------------------------------
function delcache(dirv::Vector{<:AbstractString}, arg, args...; 
        verbose::Bool = global_conf(:VERBOSE), 
        print_fun::Function = global_conf(:PRINT_FUN)
    )
    dir, args = _extract_dir(dirv, arg, args...)
    path = isempty(args) ? dir : joinpath(dir, cfname(args...))
    if isfile(path)
        rm(path; force = true, recursive = true)
        verbose && print_fun(relpath(path), " deleted!!!")
        return path
    elseif isdir(path)
        tcaches = filter(is_cfname, readdir(path))
        for tc in tcaches
            tc = joinpath(path, tc)
            rm(tc, force = true)
            verbose && print_fun(relpath(tc), " deleted!!!")
        end
        return path
    end
end

delcache(args...; kwargs...) = 
    delcache([global_conf(:CACHE_DIR)], args...; kwargs...)

## ----------------------------------------------------------------------------
function exist_cache(dirv::Vector{<:AbstractString}, arg, args...)
    dir, args = _extract_dir(dirv, arg, args...)
    cfile = joinpath(dir, cfname(args...))
    return isfile(cfile)
end
exist_cache(arg, args...) = exist_cache([global_conf(:CACHE_DIR)], arg, args...)
    
## ----------------------------------------------------------------------------
function backup_cachedir(;
        cache_dir::AbstractString = global_conf(:CACHE_DIR),
        backup_dir::AbstractString = string(cache_dir, "_backup")
    )
    tcaches = filter(is_cfname, readdir(cache_dir))
    !isdir(backup_dir) && mkpath(backup_dir)
    for file in tcaches
        src_file, dest_file = joinpath(cache_dir, file), joinpath(backup_dir, file)
        isfile(dest_file) && mtime(src_file) < mtime(dest_file) && continue
        cp(src_file, dest_file; force = true, follow_symlinks = true)
    end
    return backup_dir
end