# ContextIO module - Session recording, scopes, tape, blobs, query
# Handles the context I/O system for simulation sessions

module ContextIO

using Dates
using SHA
using Serialization
using JSON3

# Import Core types and utilities
using ..Core

# Session management (must be first - other files depend on _get_session)
include("session.jl")

# Simignore (depends on session.jl for _get_session)
include("simignore.jl")

# Blob storage
include("blob.jl")

# JSON serialization
include("json.jl")

# Tape I/O
include("tape.jl")

# Scope processing (depends on blob.jl for _write_blob)
include("scope.jl")

# Query system
include("query/handlers.jl")
include("query/wrappers.jl")
include("query/loaders.jl")

# Macros (must be last - depends on everything else)
include("macros.jl")

# Export session management
export _reset_session!, _get_session, _set_session!

# Export simignore functions
export set_simignore_rules!, simignore!, _should_ignore

# Export blob functions
export _blob_hash, _write_blob

# Export JSON functions
export _write_json, _write_commit_record, _collect_blob_refs

# Export tape functions
export _append_to_tape

# Export scope functions
export _process_scope!

# Export macros
export @sim_session, @sim_store, @sim_context, @sim_capture, @sim_commit

# Export query - Handlers
export RootHandler, SessionHandler, TapeHandler, BlobHandler
export sessions, tape, blob, exists
export _sessions_dir, _session_dir, _tape_path, _blob_path

# Export query - Wrappers
export CommitWrapper, ScopeWrapper, VariableWrapper, BlobWrapper
export session_label, commit_label, metadata, scopes, blob_refs
export label, timestamp, variables, labels, data
export name, src_type, value, blob_ref, src

# Export query - Loaders
export iterate_raw_tape, iterate_tape, load_raw_blob, load_blob

end # module ContextIO
