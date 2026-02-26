# ============================================================
# capture_types.jl — Partial capture subtypes
#
# Each PartialCapture subtype represents one independent
# slice of context that can be collected, serialized, and
# composed into a full provenance snapshot.
# ============================================================

"""Abstract base for all partial capture types."""
abstract type PartialCapture end

"""
    SettingsCapture <: PartialCapture

Snapshot of settings accessed during a capture window.
"""
struct SettingsCapture <: PartialCapture
    accessed::Dict{String, Any}   # key → resolved value at access time
    timestamp::String
end

"""
    SourceCapture <: PartialCapture

Git / source-control metadata captured once per session.
"""
struct SourceCapture <: PartialCapture
    git_commit::String
    git_branch::String
    git_dirty::Bool
    git_describe::String
end

"""
    EnvironmentCapture <: PartialCapture

Runtime environment snapshot (Julia version, hostname, etc.).
"""
struct EnvironmentCapture <: PartialCapture
    julia_version::String
    hostname::String
    os::String
    word_size::Int
    threads::Int
    timestamp::String
end

"""
    ExecutionCapture <: PartialCapture

Per-scope execution context (thread, file, line).
"""
struct ExecutionCapture <: PartialCapture
    src_file::String
    src_line::Int
    threadid::Int
    timestamp::String
end

