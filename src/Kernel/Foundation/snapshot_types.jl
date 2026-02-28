# ============================================================
# snapshot_types.jl — Partial snapshot subtypes
#
# Each PartialSnapshot subtype represents one independent
# slice of context that can be collected, serialized, and
# composed into a full provenance snapshot.
# ============================================================

"""Abstract base for all partial capture types."""
abstract type PartialSnapshot end

"""
    SettingsSnapshot <: PartialSnapshot

Snapshot of settings accessed during a capture window.
"""
struct SettingsSnapshot <: PartialSnapshot
    accessed::Dict{String, Any}   # key → resolved value at access time
    timestamp::String
end

"""
    SourceSnapshot <: PartialSnapshot

Git / source-control metadata captured once per session.
"""
struct SourceSnapshot <: PartialSnapshot
    git_commit::String
    git_branch::String
    git_dirty::Bool
    git_describe::String
end

"""
    EnvironmentSnapshot <: PartialSnapshot

Runtime environment snapshot (Julia version, hostname, etc.).
"""
struct EnvironmentSnapshot <: PartialSnapshot
    julia_version::String
    hostname::String
    os::String
    word_size::Int
    threads::Int
    timestamp::String
end

"""
    ExecutionSnapshot <: PartialSnapshot

Per-scope execution context (thread, file, line).
"""
struct ExecutionSnapshot <: PartialSnapshot
    src_file::String
    src_line::Int
    threadid::Int
    timestamp::String
end
