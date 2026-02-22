module Simuleos

include("Kernel/Kernel.jl")
include("WorkSession/WorkSession.jl")
include("ScopeReader/ScopeReader.jl")

import .Kernel: sim_init!, sim_reset!
using .WorkSession: @session_init, @session_store, @scope_inline, @scope_meta, @ctx_hash, @scope_capture, @session_commit, @session_batch_commit, @session_finalize, remember!
import .ScopeReader: project, each_commits, each_scopes, latest_scope, value, scope_table
using .ScopeReader: @scope_expand

export sim_init!, sim_reset!
export project, each_commits, each_scopes, latest_scope, value, scope_table
export @session_init, @session_store, @scope_inline, @scope_meta, @ctx_hash, @scope_capture, @session_commit, @session_batch_commit, @session_finalize
export @scope_expand
export remember!

end # module Simuleos
