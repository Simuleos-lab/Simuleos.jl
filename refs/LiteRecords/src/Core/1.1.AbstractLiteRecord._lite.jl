############################
# LiteRecord internal interface contract
#
# This module defines the internal "lite" protocol for blob-like objects.
# It is responsible for:
#   - validating what kinds of data are allowed to go into a blob,
#   - normalizing that data into a canonical, safe-to-store form,
#   - providing safe read/write/query helpers that operate on blob internals.
#
# The core building blocks are:
#   `_islite(...)`     -> "Is this value allowed in a blob?"
#   `_liteobj(...)`    -> "Turn this value into the canonical storable form."
#   `_lite_*` methods  -> safe access/mutation/introspection on blobs
#                         (get/set/haskey/iterate/etc.)
#
# EXTENSION POLICY
# ----------------
# 1. DO NOT overwrite the `_lite_*` methods in this file directly.
#
#    External code should extend the PUBLIC, underscore-less API
#    (`lite_getindex`, `lite_setindex!`, etc.), not these underscored
#    internals. The underscored versions here are the trusted core
#    that enforces invariants and assumptions about layout, safety,
#    and serialization.
#
#    In other words:
#       - You MAY add/extend `lite_foo(...)` for your own blob type.
#       - You SHOULD NOT replace `_lite_foo(...)` defined here.
#
#    The goal is: public methods are customizable and user-facing;
#    internal `_lite_*` stays consistent so we never accidentally
#    bypass safety checks.
#
#
# 2. `_liteobj(b, x)` is the ONLY supported way to ingest/store values
#    into a blob. Nothing should be inserted into a blob without going
#    through `_liteobj`.
#
#    `_liteobj` does two things:
#      (a) calls `_islite(b, x)` to verify that `x` is considered "lite"
#          for blob `b`, and errors if not;
#      (b) returns a canonical, blob-owned representation of `x`.
#
#    Default behavior implemented here:
#      - Numbers, Strings, and AbstractLiteRecord instances are returned
#        as-is (they're already "atomic" / safe).
#
#      - Vectors:
#          * must pass `_islite`, which enforces:
#              - length ≤ 10
#              - element type is itself lite
#              - NOT a vector-of-vectors, NOT a vector-of-dicts,
#                NOT a vector-of-blobs (those shapes are explicitly
#                rejected at the type level)
#          * are COPIED before storing, so later user mutation does
#            not mutate the blob. Blobs keep snapshots, not live views.
#
#      - Dict-like inputs:
#          * keys must be `String`
#          * all values must themselves be lite
#          * we materialize a fresh `LiteRecord(OrderedDict(x), Dict())`
#            so the blob holds its own stable structure.
#
#    Subtypes of `AbstractLiteRecord` MAY specialize `_liteobj` for their
#    own type if they want to change how certain inputs are wrapped.
#    Example for a custom blob subtype:
#
#        _liteobj(b::MyBlob, x::AbstractDict) =
#            MyBlob(OrderedDict(x), Dict())
#
#    The generic fallback defined here always returns `LiteRecord(...)`
#    for dict-like inputs. That is the default ingestion policy.
#
#
# 3. `_islite` defines what is allowed to exist inside a blob at all.
#
#    `_islite(::Type{<:AbstractLiteRecord}, ::Type{T})` answers:
#      "Is a value of type `T` even eligible to be stored?"
#
#    `_islite(b::AbstractLiteRecord, x)` answers:
#      "This specific runtime value `x`, with its size/keys/etc.,
#       is it acceptable right now?"
#
#    The policy is intentionally strict:
#
#      • Scalars:
#         - All `Number` subtypes are lite.
#         - `String` is lite.
#         - Any `AbstractLiteRecord` is lite.
#
#      • Vectors:
#         - A `Vector{T}` is lite iff `T` is lite AND
#           it is not a "structured" container type we disallow.
#         - We explicitly forbid:
#               Vector{<:AbstractVector}       # no vector-of-vectors
#               Vector{<:AbstractDict}         # no vector-of-dicts
#               Vector{<:AbstractLiteRecord}     # no vector-of-blobs
#           This keeps blobs shallow: you can store a short flat vector
#           of primitives, but not nested arrays / lists of dicts / etc.
#
#         - At runtime we ALSO enforce:
#               length(v) ≤ 10
#           via `_islite(b::AbstractLiteRecord, v::Vector)`.
#
#         - Heterogeneous vectors with `eltype === Any` are rejected
#           by the fallback rule that "unknown/Any-like" things
#           are not lite. That prevents sneaking in arbitrarily
#           nested junk via `Vector{Any}`.
#
#      • Dict-like things:
#         - Keys must be `String`.
#         - Every value must itself be lite (recursively).
#         - This guarantees blobs are serializable to e.g. JSON
#           in a predictable way.
#
#      • Closing the world:
#         - Everything not explicitly allowed is non-lite by default.
#           The final `_islite(..., ::Type{<:Any}) = false` and
#           `_islite(..., ::Any) = false` make that explicit.
#
#    This means blobs are intentionally shallow, small, and
#    "JSON-shaped": no arbitrary graphs, no deep trees of arrays-of-dicts,
#    no recursive blob-of-vectors-of-blobs nonsense.
#
#
# 4. Never call Base’s generic methods like `getindex`, `setindex!`,
#    `haskey`, `iterate`, etc. directly on an `AbstractLiteRecord`.
#
#    Instead, always go through the `_lite_*` helpers in this file:
#        _lite_getindex(b, ...)
#        _lite_setindex!(b, ...)
#        _lite_haskey(b, ...)
#        _lite_iterate(b, ...)
#        _lite_length(b)
#        _lite_keys(b), _lite_values(b), ...
#
#    Why:
#      - We don't want internal code to accidentally hit user-defined
#        `Base.getindex(::MyBlob, ...)` or other overrides that might
#        bypass lite validation or redirect to slow / unsafe behavior.
#
#      - The `_lite_*` helpers make it explicit which internal namespace
#        you're touching inside the blob.
#
#
# 5. Internal namespaces: `__depot__` vs `__extras__`.
#
#    Each blob has conceptually two internal dictionaries:
#        __depot__(b)   -> main user data (keys, values)
#        __extras__(b)  -> auxiliary / metadata / scratch
#
#    The helpers `_lite_getindex` and `_lite_setindex!` let you choose
#    where you are reading/writing:
#
#        _lite_getindex(b, "foo")        # look in depot
#        _lite_getindex(b, ^, "foo")     # look in extras (note the `^`)
#
#        _lite_setindex!(b, v, "foo")    # write to depot (after _liteobj)
#        _lite_setindex!(b, v, ^, "foo") # write raw to extras
#
#    That `::typeof(^)` argument is deliberate: `^` is used as a tag/sigil
#    to mean "extras namespace", so there's no ambiguity at the call site.
#
#
# TL;DR
# -----
# - `_islite` decides if something is even allowed, with strong rules
#   against nested structure and against large containers.
#
# - `_liteobj` turns an allowed thing into a canonical snapshot that
#   belongs to the blob (copying vectors, wrapping dicts, etc.).
#
# - All blob reads/writes/queries go through `_lite_*` helpers so
#   that invariants are never bypassed and it's always explicit which
#   namespace (`__depot__` vs `__extras__`) you're touching.
#
# - To customize behavior for a new blob subtype, add *more specific*
#   methods (e.g. `_liteobj(b::MyBlob, x::AbstractDict)`), or extend the
#   public `lite_*` wrappers. Do not monkey-patch the generic `_lite_*`
#   definitions here.
############################


############################
# MARK: Blob interface
############################

## ---.- .-- - .-. .-. -.- .-. -.-.-
# MARK: islite(..., type)
_islite(::Type{<:AbstractLiteRecord}, ::Type{<:Number}) = true
_islite(::Type{<:AbstractLiteRecord}, ::Type{String}) = true
_islite(L::Type{<:AbstractLiteRecord}, ::Type{Vector{T}}) where {T} = _islite(L, T)
_islite(::Type{<:AbstractLiteRecord}, ::Type{<:AbstractLiteRecord}) = true

# closing world
_islite(::Type{<:AbstractLiteRecord}, ::Type{<:Any}) = false

## ---.- .-- - .-. .-. -.- .-. -.-.-
# MARK: islite(..., object)
# _islite(b::AbstractLiteRecord, v) = _islite(typeof(b), typeof(v))

function _islite(b::AbstractLiteRecord, v::Vector) 
    length(v) > 100 && return false
    return _islite(typeof(b), eltype(v))
end

function _islite(x::AbstractLiteRecord, d::AbstractDict)
    keytype(d) == String || return  false
    for (k, v) in pairs(d)
        isa(k, String) || return false
        _islite(x, v) || return false
    end
    return true
end

# closing world
_islite(::AbstractLiteRecord, ::Any) = false

## ---.- .-- - .-. .-. -.- .-. -.-.-
# MARK: _liteobj
# Default mustly pass original object if it is lite
_liteobj(::AbstractLiteRecord, x::Number) = x
_liteobj(::AbstractLiteRecord, x::String) = x
# TODO/TAI maybe add lenght lim
function _liteobj(b::AbstractLiteRecord, x::Vector)
    _islite(b, x) || error("Non-lite vector")
    return copy(x)
end

_liteobj(::AbstractLiteRecord, x::AbstractLiteRecord) = x

# default fallback to LiteRecord
function _liteobj(b::AbstractLiteRecord, x::AbstractDict)
    _islite(b, x) || error("Non-lite dictionary")
    LiteRecord(OrderedDict(x), Dict())
end

# fallback
_liteobj(::AbstractLiteRecord, x::Any) =
    error("_liteobj not implemented for type $(typeof(x))")

    
## ---.- .-- - .-. .-. -.- .-. -.-.-
# MARK: lite_getindex

# TODO/TAI
# Think about a callback system for opening
# the getindex interface to any (custom) query resolver

# get / set by key
function _lite_getindex(x::AbstractLiteRecord,
    k::String
)
    return getindex(__depot__(x), k)
end

# dispatch on `^` as a namespace selector for extras
function _lite_getindex(x::AbstractLiteRecord,
    ::typeof(^), k::String
)
    return getindex(__extras__(x), k)
end

## ---.- .-- - .-. .-. -.- .-. -.-.-
# MARK: lite_setindex!
function _lite_setindex!(
    x::AbstractLiteRecord, v,
    k::String,
    ks...
)
    return Base.setindex!(
        __depot__(x), _liteobj(x, v), k, ks...)
end

# extras sugar
function _lite_setindex!(
    x::AbstractLiteRecord, v,
    ::typeof(^),
    k::String
)
    return Base.setindex!(__extras__(x), v, k)
end

## ---.- .-- - .-. .-. -.- .-. -.-.-
# MARK: lite_haskey
# haskey / get with default / delete / empty
function _lite_haskey(x::AbstractLiteRecord, k::String)
    return haskey(__depot__(x), k)
end


## ---.- .-- - .-. .-. -.- .-. -.-.-
# MARK: lite_get
function _lite_get(x::AbstractLiteRecord, k::String, default)
    return get(__depot__(x), k, default)
end
function _lite_get(f::Function, x::AbstractLiteRecord, k::String)
    return get(f, __depot__(x), k)
end

## ---.- .-- - .-. .-. -.- .-. -.-.-
# MARK: lite_get!
function _lite_get!(x::AbstractLiteRecord, k::String, default)
    return get!(__depot__(x), k, default)
end
function _lite_get!(f::Function, x::AbstractLiteRecord, k::String)
    return get!(f, __depot__(x), k)
end

## ---.- .-- - .-. .-. -.- .-. -.-.-
# MARK: lite_delete!
function _lite_delete!(x::AbstractLiteRecord, k::String)
    delete!(__depot__(x), k)
end

## ---.- .-- - .-. .-. -.- .-. -.-.-
# MARK: lite_empty!
function _lite_empty!(x::AbstractLiteRecord)
    empty!(__depot__(x))
end

## ---.- .-- - .-. .-. -.- .-. -.-.-
# MARK: _lite_merge!
# TODO: Think about merging
function _lite_merge!(x::AbstractLiteRecord, it)
    merge!(__depot__(x), it)
    return x
end

## ---.- .-- - .-. .-. -.- .-. -.-.-
# MARK: _lite_merge
# TODO: think more this
function _lite_merge(x::AbstractLiteRecord, it)
    depot1 = merge(__depot__(x), it)
    extras1 = copy(__extras__(x))
    return LiteRecord(depot1, extras1)
end

## ---.- .-- - .-. .-. -.- .-. -.-.-
# MARK: lite_length
function _lite_length(x::AbstractLiteRecord)
    return length(__depot__(x))
end

## ---.- .-- - .-. .-. -.- .-. -.-.-
# MARK: lite_keys
function _lite_keys(x::AbstractLiteRecord)
    return keys(__depot__(x))
end

## ---.- .-- - .-. .-. -.- .-. -.-.-
# MARK: lite_values
function _lite_values(x::AbstractLiteRecord)
    return values(__depot__(x))
end

## ---.- .-- - .-. .-. -.- .-. -.-.-
# MARK: lite_pairs
function _lite_pairs(x::AbstractLiteRecord)
    return pairs(__depot__(x))
end

## ---.- .-- - .-. .-. -.- .-. -.-.-
# MARK: lite_in
# membership (e.g., "k in blob" checks keys)
function _lite_in(k::String, x::AbstractLiteRecord)
    return in(k, keys(x))
end

## ---.- .-- - .-. .-. -.- .-. -.-.-
# MARK: lite_iterate
# iteration yields (key => value) pairs
# Note: iteration protocol is `iterate(obj[, state])`.
function _lite_iterate(x::AbstractLiteRecord)
    return iterate(pairs(__depot__(x)))
end

## ---.- .-- - .-. .-. -.- .-. -.-.-
# MARK: lite_iterate
function _lite_iterate(x::AbstractLiteRecord, state)
    return iterate(pairs(__depot__(x)), state)
end

## ---.- .-- - .-. .-. -.- .-. -.-.-
# MARK: lite_eltype
# eltype for iteration (what does each iteration yield?)
function _lite_eltype(::Type{<:AbstractLiteRecord})
    return Pair{String, Any}
end


# --- Optional: a simple "array-like" view -------------------------------------
# If you want index-by-position access (not typical for dicts, but sometimes handy),
# provide a *view* that’s explicit, so it’s not surprising.
# Example: nth key or nth Pair. These are just helpers; they don’t claim an array API.

## ---.- .-- - .-. .-. -.- .-. -.-.-
# MARK: lite_nthkey
# nth key (1-based)
function _lite_nthkey(x::AbstractLiteRecord, i0::Integer)
    i = 1
    for k in _lite_keys(x)
        i == i0 && return k
        i += 1
    end
    # TODO: make this pro
    return error("Index out of bound")
end

## ---.- .-- - .-. .-. -.- .-. -.-.-
# MARK: lite_nthpair
# nth pair
function _lite_nthpair(x::AbstractLiteRecord, i0::Integer)
    i = 1
    for p in _lite_pairs(x)
        i == i0 && return p
        i += 1
    end
    # TODO: make this pro
    return error("Index out of bound")
end

## ---.- .-- - .-. .-. -.- .-. -.-.-
# MARK: lite_json
function _lite_json(x::AbstractLiteRecord)
    js = JSON3.write(__depot__(x))
    return js
end

function _esc_newline(js::String)
    js = replace(js, "\n" => "\\n")
    return js
end

## ---.- .-- - .-. .-. -.- .-. -.-.-
# MARK: lite_jsonline
# Produce a json representation but in a single line
# Escape new lines if necesary
function _lite_jsonline(x::AbstractLiteRecord; esc_newline=false)
    js = JSON.json(__depot__(x), 0)
    esc_newline || return js
    return _esc_newline(js)
end

## ---.- .-- - .-. .-. -.- .-. -.-.-
# TODO/TAI
# - maybe add a few basic disk operations...
# - eg: readlines, readfirst


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
