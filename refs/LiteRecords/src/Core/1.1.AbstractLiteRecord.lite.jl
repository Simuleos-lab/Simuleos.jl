############################
# MARK: Blob interface
############################

## ---.- .-- - .-. .-. -.- .-. -.-.-
# MARK: liteobj
liteobj(args...) = _liteobj(args...)

## ---.- .-- - .-. .-. -.- .-. -.-.-
# MARK: lite_getindex
# get / set by key
lite_getindex(args...) = _lite_getindex(args...)

## ---.- .-- - .-. .-. -.- .-. -.-.-
# MARK: lite_setindex!
# lite_setindex!
lite_setindex!(args...) =
    _lite_setindex!(args...)

## ---.- .-- - .-. .-. -.- .-. -.-.-
# MARK: lite_haskey
# haskey / get with default / delete / empty
lite_haskey(args...) = _lite_haskey(args...)
    

## ---.- .-- - .-. .-. -.- .-. -.-.-
# MARK: lite_get
lite_get(args...) = _lite_get(args...)
    
## ---.- .-- - .-. .-. -.- .-. -.-.-
# MARK: lite_get!
lite_get!(args...) = _lite_get!(args...)

## ---.- .-- - .-. .-. -.- .-. -.-.-
# MARK: lite_delete!
lite_delete!(args...) = _lite_delete!(args...)
    
## ---.- .-- - .-. .-. -.- .-. -.-.-
# MARK: lite_empty!
lite_empty!(args...) = _lite_empty!(args...)
    
## ---.- .-- - .-. .-. -.- .-. -.-.-
# MARK: lite_merge!
# TODO: Think about merging
lite_merge!(args...) = 
    _lite_merge!(args...)

## ---.- .-- - .-. .-. -.- .-. -.-.-
# MARK: lite_merge
# TODO: think more this
lite_merge(args...) = _lite_merge(args...)

## ---.- .-- - .-. .-. -.- .-. -.-.-
# MARK: lite_length
lite_length(args...) = 
    _lite_length(args...)

## ---.- .-- - .-. .-. -.- .-. -.-.-
# MARK: lite_keys
lite_keys(args...) = _lite_keys(args...)
    
## ---.- .-- - .-. .-. -.- .-. -.-.-
# MARK: lite_values
lite_values(args...) = _lite_values(args...)
    
## ---.- .-- - .-. .-. -.- .-. -.-.-
# MARK: lite_pairs
lite_pairs(args...) = _lite_pairs(args...)
    
## ---.- .-- - .-. .-. -.- .-. -.-.-
# MARK: lite_in
# membership (e.g., "k in blob" checks keys)
lite_in(args...) = _lite_in(args...)

## ---.- .-- - .-. .-. -.- .-. -.-.-
# MARK: lite_iterate
# iteration yields (key => value) pairs
# Note: iteration protocol is `iterate(obj[, state])`.
lite_iterate(args...) = _lite_iterate(args...)

## ---.- .-- - .-. .-. -.- .-. -.-.-
# MARK: lite_eltype
# eltype for iteration (what does each iteration yield?)
lite_eltype(args...) = _lite_eltype(args...)

# --- Optional: a simple "array-like" view -------------------------------------
# If you want index-by-position access (not typical for dicts, but sometimes handy),
# provide a *view* that’s explicit, so it’s not surprising.
# Example: nth key or nth Pair. These are just helpers; they don’t claim an array API.

## ---.- .-- - .-. .-. -.- .-. -.-.-
# MARK: lite_nthkey
# nth key (1-based)
lite_nthkey(args...) = _lite_nthkey(args...)

## ---.- .-- - .-. .-. -.- .-. -.-.-
# MARK: lite_nthpair
# nth pair
lite_nthpair(args...) = _lite_nthpair(args...)

## ---.- .-- - .-. .-. -.- .-. -.-.-
# MARK: lite_json
lite_json(args...) = _lite_json(args...)

## ---.- .-- - .-. .-. -.- .-. -.-.-
# MARK: lite_json
# Produce a json representation but in a single line
# Escape new lines if necesary
lite_jsonline(args...; kwargs...) = 
    _lite_jsonline(args...; kwargs...)

# --- Example ------------------------------------------------------------------
# b = LiteRecord()
# b["a"] = 1
# b["b"] = 2
# @show haskey(b, "a")      # true
# @show length(b)           # 2
# for kv in b               # iterates key=>value pairs
#     @show kv
# end
# @show lite_nthkey(b, 1)
# delete!(b, "a")
