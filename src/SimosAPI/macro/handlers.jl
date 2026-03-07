# ------------------------------------------------------------------
# Handlers — split by namespace; each returns an Expr (already esc'd by dispatcher)
# ------------------------------------------------------------------

include("handlers/common.jl")
include("handlers/system.jl")
include("handlers/project.jl")
include("handlers/session.jl")
include("handlers/settings.jl")
include("handlers/sqlite.jl")
include("handlers/blob.jl")
include("handlers/rec.jl")
include("handlers/bind_core.jl")
include("handlers/base.jl")
include("handlers/cache.jl")
include("handlers/shared.jl")
include("handlers/query.jl")
