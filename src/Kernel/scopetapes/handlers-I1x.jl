# ScopeTapes handler navigation for .simuleos/ structure (all I1x)
# Handler types are declared in Kernel/core/types.jl.
# Path helpers are in Kernel/core/project.jl.

"""
    sessions(root::RootHandler)

Returns an iterator of `SessionHandler` for all sessions in the root.
Sessions are discovered by reading the sessions/ directory.
"""
function sessions(root::RootHandler)
    sessions_path = _sessions_dir(root)
    isdir(sessions_path) || return SessionHandler[]

    [
        SessionHandler(root, name)
        for name in readdir(sessions_path)
        if isdir(_session_dir(SessionHandler(root, name)))
    ]
end

"""
    tape(session::SessionHandler)

Returns a `TapeHandler` for the session's tape file.
"""
function tape(session::SessionHandler)
    TapeHandler(session)
end

"""
    blob(root::RootHandler, sha1::String)

Returns a `BlobHandler` for the blob with the given SHA1 hash.
"""
function blob(root::RootHandler, sha1::String)
    BlobHandler(root, sha1)
end

"""
    exists(handler::TapeHandler)

Check if the tape file exists on disk.
"""
function exists(handler::TapeHandler)
    isfile(_tape_path(handler))
end

"""
    exists(handler::BlobHandler)

Check if the blob file exists on disk.
"""
function exists(handler::BlobHandler)
    isfile(_blob_path(handler))
end
