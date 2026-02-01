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

    # Try to get git commit
    try
        git_commit = strip(read(`git -C $script_dir rev-parse HEAD`, String))
        meta["git_commit"] = git_commit
    catch
        meta["git_commit"] = nothing
    end

    # Check if git is dirty
    try
        git_status = strip(read(`git -C $script_dir status --porcelain`, String))
        meta["git_dirty"] = !isempty(git_status)
    catch
        meta["git_dirty"] = nothing
    end

    return meta
end
