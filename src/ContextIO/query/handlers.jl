# Handler structs for lazy navigation of .simuleos/ directory structure
# Handlers are cheap objects pointing to disk entities

"""
    RootHandler(path::String)

Entry point for querying a .simuleos/ directory.
"""
struct RootHandler
    path::String  # path to .simuleos/
end

"""
    SessionHandler

Points to a session directory under sessions/<label>/.
"""
struct SessionHandler
    root::RootHandler
    label::String
end

"""
    TapeHandler

Points to a context.tape.jsonl file within a session.
"""
struct TapeHandler
    session::SessionHandler
end

"""
    BlobHandler

Points to a blob file under blobs/<sha1>.jls.
"""
struct BlobHandler
    root::RootHandler
    sha1::String
end

# Path helpers

function _sessions_dir(root::RootHandler)
    joinpath(root.path, "sessions")
end

function _session_dir(session::SessionHandler)
    safe_label = replace(session.label, r"[^\w\-]" => "_")
    joinpath(_sessions_dir(session.root), safe_label)
end

function _tape_path(tape::TapeHandler)
    joinpath(_session_dir(tape.session), "tapes", "context.tape.jsonl")
end

function _blob_path(bh::BlobHandler)
    joinpath(bh.root.path, "blobs", "$(bh.sha1).jls")
end

# Navigation methods

"""
    sessions(root::RootHandler)

Returns an iterator of `SessionHandler` for all sessions in the root.
Sessions are discovered lazily by reading the sessions/ directory.
"""
function sessions(root::RootHandler)
    sessions_path = _sessions_dir(root)
    isdir(sessions_path) || return SessionHandler[]

    [
        SessionHandler(root, name)
        for name in readdir(sessions_path)
        if isdir(joinpath(sessions_path, name))
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
