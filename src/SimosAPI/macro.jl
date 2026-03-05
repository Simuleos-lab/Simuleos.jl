# ============================================================
# SimosAPI/macro.jl — Unified @simos dispatch macro
# ============================================================

const _SimWS = WorkSession
const _SimKrn = Kernel
const _SimSQLI = SQLiteIndex
const _SQLite = SQLite
const _SimosAPI = SimosAPI

"""
    SIMOS_GLOBAL_LOCK

Process-wide reentrant lock serializing all `@simos` operations.
Acts as a GIL: every `@simos` call acquires this lock before
executing, ensuring thread-safe access to `SIMOS[]` and all
`WorkSession` mutable state.
"""
const SIMOS_GLOBAL_LOCK = ReentrantLock()

"""
    SIMOS_GLOBAL_LOCK_ENABLED

Runtime flag controlling whether `@simos` acquires `SIMOS_GLOBAL_LOCK`.
Set to `false` to disable locking (e.g., single-threaded workloads).
Default: `true`.
"""
const SIMOS_GLOBAL_LOCK_ENABLED = Ref(true)

include("macro/parse.jl")
include("macro/runtime.jl")
include("macro/handlers.jl")
include("macro/dispatch.jl")
include("macro/help.jl")
