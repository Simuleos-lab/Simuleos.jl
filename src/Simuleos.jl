module Simuleos

include("Kernel/Kernel.jl")
include("WorkSession/WorkSession.jl")
include("ScopeReader/ScopeReader.jl")

import .Kernel: sim_init!, sim_reset!
import .WorkSession: remember!
import .WorkSession: simignore!, capture_filter_register!, capture_filter_bind!, capture_filters_snapshot!, capture_filters_reset!
import .ScopeReader: project, each_commits, each_scopes, latest_scope, value, scope_table

export sim_init!, sim_reset!
export project, each_commits, each_scopes, latest_scope, value, scope_table
export remember!
export simignore!, capture_filter_register!, capture_filter_bind!, capture_filters_snapshot!, capture_filters_reset!

include("simos_macro.jl")
export @simos

end # module Simuleos
