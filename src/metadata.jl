# Metadata capture for git, Julia version, timestamps

using Dates

function _capture_metadata(script_path)::Dict{String, Any}
    meta = Dict{String, Any}()

    # Timestamp
    meta["timestamp"] = string(now())

    # Julia version
    meta["julia_version"] = string(VERSION)

    # Hostname
    meta["hostname"] = gethostname()

    # Script path
    meta["script_path"] = script_path

    # Git information
    script_dir = dirname(script_path)
    if isempty(script_dir)
        script_dir = pwd()
    end

    # Try to get git information using GitHandler
    try
        gh = GitHandler(script_dir)
        meta["git_commit"] = hash(gh)
        meta["git_dirty"] = dirty(gh)
    catch
        meta["git_commit"] = nothing
        meta["git_dirty"] = nothing
    end

    return meta
end
