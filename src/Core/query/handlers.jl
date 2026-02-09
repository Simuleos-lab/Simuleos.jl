# Handler navigation and path helpers for .simuleos/ directory structure
# Handler types are declared in Core/types.jl

# Path helpers

function _sessions_dir(root::Core.RootHandler)
    joinpath(root.path, "sessions")
end

function _session_dir(session::Core.SessionHandler)
    safe_label = replace(session.label, r"[^\w\-]" => "_")
    joinpath(_sessions_dir(session.root), safe_label)
end

function _tape_path(tape::Core.TapeHandler)
    joinpath(_session_dir(tape.session), "tapes", "context.tape.jsonl")
end

function _blob_path(bh::Core.BlobHandler)
    joinpath(bh.root.path, "blobs", "$(bh.sha1).jls")
end

# Navigation methods

"""
    sessions(root::RootHandler)

Returns an iterator of `SessionHandler` for all sessions in the root.
Sessions are discovered lazily by reading the sessions/ directory.
"""
function sessions(root::Core.RootHandler)
    sessions_path = _sessions_dir(root)
    isdir(sessions_path) || return Core.SessionHandler[]

    [
        Core.SessionHandler(root, name)
        for name in readdir(sessions_path)
        if isdir(joinpath(sessions_path, name))
    ]
end

"""
    tape(session::SessionHandler)

Returns a `TapeHandler` for the session's tape file.
"""
function tape(session::Core.SessionHandler)
    Core.TapeHandler(session)
end

"""
    blob(root::RootHandler, sha1::String)

Returns a `BlobHandler` for the blob with the given SHA1 hash.
"""
function blob(root::Core.RootHandler, sha1::String)
    Core.BlobHandler(root, sha1)
end

"""
    exists(handler::TapeHandler)

Check if the tape file exists on disk.
"""
function exists(handler::Core.TapeHandler)
    isfile(_tape_path(handler))
end

"""
    exists(handler::BlobHandler)

Check if the blob file exists on disk.
"""
function exists(handler::Core.BlobHandler)
    isfile(_blob_path(handler))
end
