# TODO: Move to a data io interface

# # ------------------------------------------------------------------
# # Base save/load
# _load(file) = endswith(file, ".jls") ? deserialize(file) : FileIO.load(file)

# _save(file, dat) = endswith(file, ".jls") ? serialize(file, dat) : FileIO.save(file, dat)

# # ------------------------------------------------------------------
# # Based in DrWatson

# # TODO: Add to project config

# const DATA_KEY = :dat
# const GIT_COMMIT_KEY = :gitcommit
# const GIT_PATCH_KEY = :gitpatch
# const DIRTY_SUFFIX = "_dirty"
# const SHORT_HASH_LENGTH = 7
# const ERROR_LOGGER = SimpleLogger(stdout, Logging.Error)

# # ------------------------------------------------------------------

# function ldat(arg, args...; 
#         print_fun::Function = Base.println, 
#         load_fun::Function = _load, 
#         mkdir::Bool = true,
#         verbose::Bool = false,
#         msg::AbstractString = "",
#     )

#     datfile = dfname(arg, args...)
#     mkdir && mkpath(dirname(datfile))
#     file_dat = load_fun(datfile)
#     dat = file_dat[DATA_KEY]
#     if verbose 
#         commit_hash = get(file_dat, GIT_COMMIT_KEY, "none")
#         _io_print(
#             print_fun, "DATA LOADED", msg, dat, datfile, 
#             "\ncommit: ", _cut_hash(commit_hash)
#         )
#     end
#     return (datfile, dat)
# end

# function ldat(f::Function, arg, args...; 
#         load_fun::Function = _load, 
#         addtag::Bool = false,
#         save_fun::Function = _save, 
#         kwargs...
#     )
#     datfile = dfname(arg, args...)
#     !isfile(datfile) && sdat(f(), datfile; save_fun, addtag, kwargs...)
#     return ldat(datfile; load_fun, kwargs...)
# end

# # ------------------------------------------------------------------
# function sdat(dat, arg, args...; 
#         print_fun::Function = Base.println, 
#         addtag::Bool = false,
#         save_fun::Function = _save,
#         mkdir::Bool = true,
#         verbose::Bool = false, 
#         msg::AbstractString = "",
#     )
#     datfile = dfname(arg, args...)
#     mkdir && mkpath(dirname(datfile))

#     L = verbose ? global_logger() : ERROR_LOGGER
#     with_logger(L) do
#         dict = Dict(DATA_KEY => dat)
#         tagdat = addtag ? DrWatson.tag!(dict) : dict
#         save_fun(datfile, tagdat)
#         commit_hash = get(tagdat, GIT_COMMIT_KEY, "none")
#         verbose && verbose && _io_print(
#             print_fun, "DATA SAVED", msg, dat, datfile, 
#             "\ncommit: ", _cut_hash(commit_hash)
#         )
#         return (datfile, dat)
#     end
# end

# sdat(f::Function, arg, args...; kwargs...) = sdat(f(), arg, args...; kwargs...) 

# # ------------------------------------------------------------------
# function dhash(datfile, l = SHORT_HASH_LENGTH) 
#     hash = get(_load(datfile), GIT_COMMIT_KEY, "")
#     _cut_hash(hash, l)
# end

# function _cut_hash(commit_hash, l = SHORT_HASH_LENGTH)
#     short_hash = first(commit_hash, l)
#     endswith(commit_hash, DIRTY_SUFFIX) ? string(short_hash, DIRTY_SUFFIX) : short_hash
# end

# lgitpatch(args...) = get(ldat(args...), GIT_PATCH_KEY, "")

# # ------------------------------------------------------------------
# function withdat(f::Function, mode::Symbol, arg, args...;
#         print_fun::Function = Base.println, 
#         addtag::Bool = false,
#         save_fun::Function = _save,
#         load_fun::Function = _load, 
#         mkdir::Bool = true,
#         verbose::Bool = false, 
#         msg::AbstractString = "",
#     )

#     datfile = dfname(arg, args...)
#     if mode == :get
#         isfile(datfile) || return (datfile, f())
#         return ldat(datfile; print_fun, load_fun, mkdir, verbose, msg)
#     elseif mode == :get! 
#         isfile(datfile) || sdat(f, datfile; print_fun, addtag, save_fun, mkdir, verbose, msg)
#         return ldat(datfile; print_fun, load_fun, mkdir, verbose, msg)
#     elseif mode == :set! || mode == :write! || mode == :save!
#         return sdat(f, datfile; print_fun, addtag, save_fun, mkdir, verbose, msg)
#     elseif mode == :read || mode == :load
#         return ldat(datfile; print_fun, load_fun, mkdir, verbose, msg)
#     elseif mode == :noread || mode == :dry
#         return ("", f())
#     end
#     error("invalid mode: valids are [:get, :get!, :set!/:write!/:save!, :read/:load, :noread/:dry]")
# end

# withdat(dat::Any, mode::Symbol, arg, args...; kwargs...) = withdat(() -> dat, mode, arg, args...; kwargs...)