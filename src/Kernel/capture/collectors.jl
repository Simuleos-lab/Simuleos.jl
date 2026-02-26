# ============================================================
# capture/collectors.jl — Pure collection functions
#
# Each collector returns a PartialCapture subtype. They are
# pure (no side effects) and safe to call from any context.
# ============================================================

"""
    capture_source(gh) -> SourceCapture

Collect git/source metadata from a GitHandler.
Returns a zeroed-out capture when `gh` is `nothing`.
"""
function capture_source(gh::Nothing)::SourceCapture
    return SourceCapture("", "", false, "")
end

function capture_source(gh::GitHandler)::SourceCapture
    return SourceCapture(
        git_hash(gh),
        git_branch(gh),
        git_dirty(gh),
        git_describe(gh),
    )
end

"""
    capture_environment() -> EnvironmentCapture

Collect runtime environment metadata.
"""
function capture_environment()::EnvironmentCapture
    return EnvironmentCapture(
        string(VERSION),
        gethostname(),
        string(Sys.KERNEL),
        Sys.WORD_SIZE,
        Threads.nthreads(),
        string(Dates.now()),
    )
end

"""
    capture_execution(src_file, src_line) -> ExecutionCapture

Collect per-scope execution context.
"""
function capture_execution(src_file::String, src_line::Int)::ExecutionCapture
    return ExecutionCapture(
        src_file,
        src_line,
        Threads.threadid(),
        string(Dates.now()),
    )
end

"""
    capture_execution() -> ExecutionCapture

Collect execution context without source location.
"""
function capture_execution()::ExecutionCapture
    return capture_execution("", 0)
end

