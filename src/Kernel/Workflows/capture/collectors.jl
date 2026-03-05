# ============================================================
# capture/collectors.jl — Pure collection functions
#
# Each collector returns a SimuleosDataClass subtype (a frozen
# slice of state). Pure (no side effects), safe from any context.
# ============================================================

"""
    capture_source(gh) -> SrcCodebaseV1

Collect git/source metadata from a GitHandler.
Returns a zeroed-out capture when `gh` is `nothing`.
"""
function capture_source(gh::Nothing)::SrcCodebaseV1
    return SrcCodebaseV1("", "", false, "")
end

function capture_source(gh::GitHandler)::SrcCodebaseV1
    return SrcCodebaseV1(
        git_hash(gh),
        git_branch(gh),
        git_dirty(gh),
        git_describe(gh),
    )
end

"""
    capture_environment() -> SrcRuntimeHostV1

Collect runtime environment metadata.
"""
function capture_environment()::SrcRuntimeHostV1
    return SrcRuntimeHostV1(
        string(VERSION),
        gethostname(),
        string(Sys.KERNEL),
        Sys.WORD_SIZE,
        Threads.nthreads(),
        string(Dates.now()),
    )
end

"""
    capture_execution(src_file, src_line) -> SrcExecutionSiteV1

Collect per-scope execution context.
"""
function capture_execution(src_file::String, src_line::Int)::SrcExecutionSiteV1
    return SrcExecutionSiteV1(
        src_file,
        src_line,
        Threads.threadid(),
        string(Dates.now()),
    )
end

"""
    capture_execution() -> SrcExecutionSiteV1

Collect execution context without source location.
"""
function capture_execution()::SrcExecutionSiteV1
    return capture_execution("", 0)
end
