module Simuleos

include("Kernel/Kernel.jl")
include("WorkSession/WorkSession.jl")
include("ScopeReader/ScopeReader.jl")
include("SQLiteIndex/SQLiteIndex.jl")
include("SimosAPI/SimosAPI.jl")

import .Kernel: sim_init!, sim_reset!
import .WorkSession: remember!
import .WorkSession: simignore!, capture_filter_register!, capture_filter_bind!, capture_filters_snapshot!, capture_filters_reset!
import .ScopeReader: project, each_commits, each_scopes, latest_scope, value, scope_table
import .SQLiteIndex: sqlite_index_path, sqlite_index_open, sqlite_index_rebuild!, sqlite_index_refresh!
import .SimosAPI: @simos, SIMOS_GLOBAL_LOCK, SIMOS_GLOBAL_LOCK_ENABLED

export sim_init!, sim_reset!
export project, each_commits, each_scopes, latest_scope, value, scope_table
export sqlite_index_path, sqlite_index_open, sqlite_index_rebuild!, sqlite_index_refresh!
export remember!
export simignore!, capture_filter_register!, capture_filter_bind!, capture_filters_snapshot!, capture_filters_reset!
export @simos, SIMOS_GLOBAL_LOCK, SIMOS_GLOBAL_LOCK_ENABLED

end # module Simuleos
