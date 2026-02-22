# ============================================================
# cache.jl — WorkSession-facing keyed cache API
# ============================================================

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

function _remember_store!(namespace, ctx_hash, value)
    _, proj = _require_active_worksession_and_project()
    return _Kernel.cache_store!(proj, namespace, ctx_hash, value)
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
Returns `(value, :hit|:miss)`.
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
