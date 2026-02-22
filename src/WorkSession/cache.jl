# ============================================================
# cache.jl — WorkSession-facing keyed cache API
# ============================================================

function _resolve_cache_ctx_hash(ws::_Kernel.WorkSession; ctx = nothing, ctx_hash = nothing)::String
    has_ctx = !isnothing(ctx)
    has_ctx_hash = !isnothing(ctx_hash)
    has_ctx == has_ctx_hash &&
        error("remember! expects exactly one of `ctx` or `ctx_hash`.")

    if has_ctx
        label = strip(String(ctx))
        isempty(label) && error("remember! `ctx` label must be a non-empty string.")
        haskey(ws.context_hash_reg, label) ||
            error("Unknown context hash label `$(label)`. Compute it first with @ctx_hash.")
        return ws.context_hash_reg[label]
    end

    h = strip(String(ctx_hash))
    isempty(h) && error("remember! `ctx_hash` must be a non-empty string.")
    return h
end

"""
    remember!(namespace; ctx=..., ctx_hash=..., tags=String[]) do
        ...
    end

Compute-or-reuse a cached value using a namespace plus context hash.
Resolve named context hashes from the active work session (`ctx`) or pass a hash
directly (`ctx_hash`).
Returns `(value, :hit|:miss)`.
"""
function remember!(f::Function, namespace;
        ctx = nothing,
        ctx_hash = nothing,
        tags = String[]
    )
    ws, proj = _require_active_worksession_and_project()
    resolved_ctx_hash = _resolve_cache_ctx_hash(ws; ctx=ctx, ctx_hash=ctx_hash)
    return _Kernel.cache_remember!(f, proj, namespace, resolved_ctx_hash; tags=tags)
end

remember!(f::Function, namespace::Symbol; kw...) = remember!(f, String(namespace); kw...)
