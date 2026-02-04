# JSONL tape I/O for recording simulation sessions

using ..Core: Session

function _append_to_tape(session::Session, commit_label::String="")
    # Use session-specific directory
    safe_label = replace(session.label, r"[^\w\-]" => "_")
    session_dir = joinpath(session.root_dir, "sessions", safe_label)
    tapes_dir = joinpath(session_dir, "tapes")
    mkpath(tapes_dir)

    tape_path = joinpath(tapes_dir, "context.tape.jsonl")

    open(tape_path, "a") do io
        _write_commit_record(io, session, commit_label)
        println(io)
    end
end
