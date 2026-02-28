# ============================================================
# cache.jl — Keyed cache backend (blob-backed values + JSON metadata)
# ============================================================

const CACHE_DIR = "cache"
const CACHE_ENTRIES_DIR = "entries"

_cache_root_dir(simuleos_dir::String) = joinpath(simuleos_dir, CACHE_DIR)
_cache_entries_dir(simuleos_dir::String) = joinpath(_cache_root_dir(simuleos_dir), CACHE_ENTRIES_DIR)
_cache_entries_dir(proj::SimuleosProject) = _cache_entries_dir(proj.simuleos_dir)

function _cache_namespace(namespace)::String
    ns = strip(String(namespace))
    isempty(ns) && error("Cache namespace must be a non-empty string.")
    return ns
end

function _cache_ctx_hash(ctx_hash)::String
    h = strip(String(ctx_hash))
    isempty(h) && error("Cache context hash must be a non-empty string.")
    return h
end

_cache_value_key(namespace::String, ctx_hash::String) = ("cache_value_v1", namespace, ctx_hash)
_cache_value_ref(namespace::String, ctx_hash::String)::BlobRef = blob_ref(_cache_value_key(namespace, ctx_hash))
_cache_entry_id(namespace::String, ctx_hash::String)::String =
    blob_ref(("cache_entry_v1", namespace, ctx_hash)).hash
_cache_entry_path(proj::SimuleosProject, namespace::String, ctx_hash::String)::String =
    joinpath(_cache_entries_dir(proj), _cache_entry_id(namespace, ctx_hash) * ".json")

function _cache_tags(tags)::Vector{String}
    return String[string(t) for t in tags]
end

function _cache_hits(v)::Int
    if v isa Integer
        return Int(v)
    end
    try
        return parse(Int, string(v))
    catch
        return 0
    end
end

function _cache_meta_seed(namespace::String, ctx_hash::String, ref::BlobRef; tags = String[])::Dict{String, Any}
    now_str = string(Dates.now())
    return Dict{String, Any}(
        "namespace" => namespace,
        "ctx_hash" => ctx_hash,
        "blob_ref" => ref.hash,
        "tags" => _cache_tags(tags),
        "created_at" => now_str,
        "last_access_at" => now_str,
        "hits" => 0,
    )
end

function _cache_meta_touch!(proj::SimuleosProject, namespace::String, ctx_hash::String, ref::BlobRef; tags = String[])::Dict{String, Any}
    path = _cache_entry_path(proj, namespace, ctx_hash)
    meta = _read_json_file_or_empty(path)
    if isempty(meta)
        meta = _cache_meta_seed(namespace, ctx_hash, ref; tags=tags)
    else
        meta["namespace"] = namespace
        meta["ctx_hash"] = ctx_hash
        meta["blob_ref"] = ref.hash
        if !isempty(tags) && (!haskey(meta, "tags") || isempty(get(meta, "tags", Any[])))
            meta["tags"] = _cache_tags(tags)
        end
    end

    meta["hits"] = _cache_hits(get(meta, "hits", 0)) + 1
    meta["last_access_at"] = string(Dates.now())
    _write_json_file(path, meta)
    return meta
end

function _cache_meta_write_miss!(proj::SimuleosProject, namespace::String, ctx_hash::String, ref::BlobRef; tags = String[])::Dict{String, Any}
    path = _cache_entry_path(proj, namespace, ctx_hash)
    meta = _cache_meta_seed(namespace, ctx_hash, ref; tags=tags)
    _write_json_file(path, meta)
    return meta
end

"""
    cache_tryload(proj, namespace, ctx_hash; tags=String[]) -> (hit::Bool, value)

Lookup a cached value. On hit, refresh cache metadata.
"""
function cache_tryload(proj::SimuleosProject, namespace, ctx_hash; tags = String[])
    ns = _cache_namespace(namespace)
    ch = _cache_ctx_hash(ctx_hash)
    tag_list = _cache_tags(tags)

    storage = proj.blobstorage
    ref = _cache_value_ref(ns, ch)
    exists(storage, ref) || return (false, nothing)

    value = blob_read(storage, ref)
    _cache_meta_touch!(proj, ns, ch, ref; tags=tag_list)
    return (true, value)
end

"""
    cache_store!(proj, namespace, ctx_hash, value; tags=String[]) -> (; ref, status)

Store a cache value and write cache metadata.
Returns a structured outcome with:
- `ref`: canonical blob reference for the cache key
- `status`: `:stored` or `:already_exists`
"""
function cache_store!(proj::SimuleosProject, namespace, ctx_hash, value; tags = String[])
    ns = _cache_namespace(namespace)
    ch = _cache_ctx_hash(ctx_hash)
    tag_list = _cache_tags(tags)

    storage = proj.blobstorage
    value_key = _cache_value_key(ns, ch)
    ref = _cache_value_ref(ns, ch)

    try
        blob_write(storage, value_key, value)
        _cache_meta_write_miss!(proj, ns, ch, ref; tags=tag_list)
        return (ref = ref, status = :stored)
    catch err
        if err isa BlobAlreadyExistsError
            _cache_meta_touch!(proj, ns, ch, ref; tags=tag_list)
            return (ref = ref, status = :already_exists)
        end
        rethrow()
    end
end

"""
    cache_remember!(f, proj, namespace, ctx_hash; tags=String[]) -> (value, status)

Blob-backed keyed cache primitive used by higher-level workflow APIs.
`status` is one of:
- `:hit` (loaded from cache)
- `:miss` (computed and stored by this caller)
- `:race_lost` (computed locally, but another writer stored first; returns canonical cached value)
"""
function cache_remember!(f::Function, proj::SimuleosProject, namespace, ctx_hash; tags = String[])
    hit, value = cache_tryload(proj, namespace, ctx_hash; tags=tags)
    if hit
        return (value, :hit)
    end

    local_value = f()
    store_result = cache_store!(proj, namespace, ctx_hash, local_value; tags=tags)
    if store_result.status === :stored
        return (local_value, :miss)
    end

    canonical_value = blob_read(proj.blobstorage, store_result.ref)
    return (canonical_value, :race_lost)
end
