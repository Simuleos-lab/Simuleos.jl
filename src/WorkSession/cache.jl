# ============================================================
# cache.jl — WorkSession-facing keyed cache API
# ============================================================

function _ctx_hash_digest(parts...)::String
    return _Kernel.blob_ref(("ctx_hash_v1", parts...)).hash
end

function _ctx_hash_extra_parts(extra_parts)::Vector{Any}
    isnothing(extra_parts) && return Any[]

    if extra_parts isa NamedTuple
        parts = Any[]
        for (k, v) in pairs(extra_parts)
            push!(parts, (String(k), v))
        end
        return parts
    end

    if extra_parts isa Tuple || extra_parts isa AbstractVector
        return Any[extra_parts...]
    end

    return Any[extra_parts]
end

function _ctx_hash_compose(ctx_hash, extra_parts = nothing)::String
    h = strip(String(ctx_hash))
    isempty(h) && error("Context hash must be a non-empty string.")

    parts = _ctx_hash_extra_parts(extra_parts)
    isempty(parts) && return h
    return _ctx_hash_digest("ctx_hash_compose_v1", h, parts)
end

function _ctx_hash_from_named_entries(label::AbstractString, entries::AbstractVector{<:Tuple})::String
    key_label = strip(String(label))
    isempty(key_label) && error("@ctx_hash label must be a non-empty string.")

    normalized = Tuple{String, Any}[]
    for item in entries
        length(item) == 2 || error("@ctx_hash internal error: expected (name, value) entries.")
        name = strip(String(item[1]))
        isempty(name) && error("@ctx_hash variable labels must be non-empty.")
        push!(normalized, (name, item[2]))
    end

    # Keep the original @ctx_hash key layout to avoid unnecessary cache invalidation.
    return _ctx_hash_digest(key_label, normalized)
end

function _resolve_cache_ctx_hash(ws::_Kernel.WorkSession; ctx = nothing, ctx_hash = nothing, ctx_extra = nothing)::String
    has_ctx = !isnothing(ctx)
    has_ctx_hash = !isnothing(ctx_hash)
    has_ctx == has_ctx_hash &&
        error("remember! expects exactly one of `ctx` or `ctx_hash`.")

    local base_ctx_hash
    if has_ctx
        label = strip(String(ctx))
        isempty(label) && error("remember! `ctx` label must be a non-empty string.")
        haskey(ws.context_hash_reg, label) ||
            error("Unknown context hash label `$(label)`. Compute it first with @ctx_hash.")
        base_ctx_hash = ws.context_hash_reg[label]
    else
        h = strip(String(ctx_hash))
        isempty(h) && error("remember! `ctx_hash` must be a non-empty string.")
        base_ctx_hash = h
    end

    return _ctx_hash_compose(base_ctx_hash, ctx_extra)
end

function _remember_namespace(slot::Symbol)::String
    return "slot:" * String(slot)
end

function _remember_namespace(slots::AbstractVector{Symbol})::String
    isempty(slots) && error("@remember target tuple cannot be empty.")
    return "slots:" * join(String.(slots), ",")
end

function _remember_tryload(namespace, ctx_hash)
    _, proj = _require_active_worksession_and_project()
    return _Kernel.cache_tryload(proj, namespace, ctx_hash)
end

function _remember_store_result!(namespace, ctx_hash, value)
    _, proj = _require_active_worksession_and_project()
    store_result = _Kernel.cache_store!(proj, namespace, ctx_hash, value)
    if store_result.status === :stored
        return (value, :miss)
    end

    canonical_value = _Kernel.blob_read(proj.blobstorage, store_result.ref)
    return (canonical_value, :race_lost)
end

"""
    remember!(namespace; ctx=..., ctx_hash=..., ctx_extra=nothing, tags=String[]) do
        ...
    end

Compute-or-reuse a cached value using a namespace plus context hash.
Resolve named context hashes from the active work session (`ctx`) or pass a hash
directly (`ctx_hash`). `ctx_extra` lets callers compose additional
disambiguation data into the resolved context hash without changing the original
named hash registry entry.
Returns `(value, :hit|:miss|:race_lost)`.
"""
function remember!(f::Function, namespace;
        ctx = nothing,
        ctx_hash = nothing,
        ctx_extra = nothing,
        tags = String[]
    )
    ws, proj = _require_active_worksession_and_project()
    resolved_ctx_hash = _resolve_cache_ctx_hash(ws; ctx=ctx, ctx_hash=ctx_hash, ctx_extra=ctx_extra)
    return _Kernel.cache_remember!(f, proj, namespace, resolved_ctx_hash; tags=tags)
end

remember!(f::Function, namespace::Symbol; kw...) = remember!(f, String(namespace); kw...)
