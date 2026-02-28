# ============================================================
# settings.jl — Layered settings system entrypoint
# ============================================================

const __MISSING__ = :__MISSING__

include("stack.jl")
include("registry.jl")
include("sources.jl")
include("explain.jl")
