# ScopeTapes base primitives (all I0x)
# Record type definitions are centralized in `core/types-I0x.jl`.

# Backward-compatible keyword constructor (formerly provided by @kwdef).
function ScopeStage(;
        captures = Scope[],
        current_scope = Scope(),
        blob_refs = Dict{Symbol, BlobRef}()
    )
    return ScopeStage(captures, current_scope, blob_refs)
end
