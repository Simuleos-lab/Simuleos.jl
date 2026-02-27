# ============================================================
# capture/collectors.jl — Pure collection functions
#
# Each collector returns a PartialSnapshot subtype (a frozen
# slice of state). Pure (no side effects), safe from any context.
# ============================================================

"""
    capture_source(gh) -> SourceSnapshot

Collect git/source metadata from a GitHandler.
Returns a zeroed-out capture when `gh` is `nothing`.
"""
function capture_source(gh::Nothing)::SourceSnapshot
    return SourceSnapshot("", "", false, "")
end

function capture_source(gh::GitHandler)::SourceSnapshot
    return SourceSnapshot(
        git_hash(gh),
        git_branch(gh),
        git_dirty(gh),
        git_describe(gh),
    )
end

"""
    capture_environment() -> EnvironmentSnapshot

Collect runtime environment metadata.
"""
function capture_environment()::EnvironmentSnapshot
    return EnvironmentSnapshot(
        string(VERSION),
        gethostname(),
        string(Sys.KERNEL),
        Sys.WORD_SIZE,
        Threads.nthreads(),
        string(Dates.now()),
    )
end

"""
    capture_execution(src_file, src_line) -> ExecutionSnapshot

Collect per-scope execution context.
"""
function capture_execution(src_file::String, src_line::Int)::ExecutionSnapshot
    return ExecutionSnapshot(
        src_file,
        src_line,
        Threads.threadid(),
        string(Dates.now()),
    )
end

"""
    capture_execution() -> ExecutionSnapshot

Collect execution context without source location.
"""
function capture_execution()::ExecutionSnapshot
    return capture_execution("", 0)
end

