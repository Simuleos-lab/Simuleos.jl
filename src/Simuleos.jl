module Simuleos

include("Kernel/Kernel.jl")
include("WorkSession/WorkSession.jl")
include("ScopeReader/ScopeReader.jl")

import .Kernel: sim_init!, sim_reset!
using .WorkSession: @session_init, @session_store, @scope_inline, @scope_meta, @scope_capture, @session_commit
import .ScopeReader: project, each_scopes, latest_scope, value
using .ScopeReader: @scope_expand

export sim_init!, sim_reset!
export project, each_scopes, latest_scope, value
export @session_init, @session_store, @scope_inline, @scope_meta, @scope_capture, @session_commit
export @scope_expand

end # module Simuleos
