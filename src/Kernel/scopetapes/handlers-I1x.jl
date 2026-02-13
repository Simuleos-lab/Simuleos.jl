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
    exists(handler::TapeHandler)

Check if the tape file exists on disk.
"""
function exists(handler::TapeHandler)
    isfile(_tape_path(handler))
end
