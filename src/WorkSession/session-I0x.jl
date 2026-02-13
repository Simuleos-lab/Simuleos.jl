# WorkSession metadata capture (no SimOs integration)

# ==================================
# Metadata Capture
# ==================================

"""
    _capture_worksession_metadata(script_path, git_handler=nothing)

I0x — pure metadata capture (no SimOs integration)

Capture metadata for a work session: timestamp, Julia version, hostname, git info.
"""
function _capture_worksession_metadata(
        script_path,
        git_handler = Kernel.GitHandler(dirname(script_path))
    )::Dict{String,Any}
    meta = Dict{String,Any}()

    # Timestamp
    meta["timestamp"] = string(Dates.now())

    # Julia version
    meta["julia_version"] = string(VERSION)

    # Hostname
    meta["hostname"] = gethostname()

    # Script path
    meta["script_path"] = script_path

    # Git information
    if !isnothing(git_handler)
        try
            meta["git_commit"] = Kernel.git_hash(git_handler)
            meta["git_dirty"] = Kernel.git_dirty(git_handler)
        catch
            meta["git_commit"] = nothing
            meta["git_dirty"] = nothing
        end
    end

    return meta
end
