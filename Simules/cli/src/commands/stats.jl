import Dates
import Printf
import UUIDs

struct SessionStats
    session_id::Base.UUID
    labels::Vector{String}
    timestamp::Union{Nothing, Dates.DateTime}
    commit_count::Int
    scope_count::Int
    variable_count::Int
    inline_variable_count::Int
    blob_variable_count::Int
    void_variable_count::Int
    tape_fragment_count::Int
    tape_bytes::Int
end

struct ProjectStats
    generated_at::Dates.DateTime
    project_root::String
    simuleos_dir::String
    project_id::Union{Nothing, String}
    session_count::Int
    commit_count::Int
    scope_count::Int
    variable_count::Int
    inline_variable_count::Int
    blob_variable_count::Int
    void_variable_count::Int
    tape_fragment_count::Int
    tape_bytes::Int
    blob_file_count::Int
    blob_bytes::Int
    latest_session::Union{Nothing, SessionStats}
end

function print_stats_help(io::IO = stdout)
    println(io, "Usage:")
    println(io, "  simules stats [path]")
    println(io, "  simules stats --project <path>")
    println(io, "")
    println(io, "Options:")
    println(io, "  -h, --help       Show this help.")
    println(io, "  --project <path> Explicit project root or nested path.")
end

function _stats_project_path(args::Vector{String})::Union{Nothing, String}
    project_path = pwd()
    got_positional = false
    i = 1
    while i <= length(args)
        arg = args[i]
        if arg == "-h" || arg == "--help"
            return nothing
        end
        if arg == "--project"
            i += 1
            i > length(args) && error("Missing value for --project.")
            project_path = args[i]
        elseif startswith(arg, "--project=")
            project_path = split(arg, "="; limit=2)[2]
        elseif startswith(arg, "-")
            error("Unknown option: $(arg)")
        else
            got_positional && error("Only one positional project path is supported.")
            got_positional = true
            project_path = arg
        end
        i += 1
    end
    return project_path
end

function _tape_files(tape_path::String)::Vector{String}
    if isdir(tape_path)
        return Simuleos.Kernel._fragment_files(tape_path)
    end
    isfile(tape_path) && return String[tape_path]
    return String[]
end

function _sum_file_sizes(files::Vector{String})::Int
    total = 0
    for path in files
        total += filesize(path)
    end
    return total
end

function _session_tape_stats(
        project_driver::Simuleos.Kernel.SimuleosProject,
        session_id::Base.UUID
    )::NamedTuple
    commit_count = 0
    scope_count = 0
    variable_count = 0
    inline_variable_count = 0
    blob_variable_count = 0
    void_variable_count = 0

    tape_path = Simuleos.Kernel.tape_path(project_driver, session_id)
    tape_files = _tape_files(tape_path)
    tape_fragment_count = length(tape_files)
    tape_bytes = _sum_file_sizes(tape_files)

    tape = Simuleos.Kernel.TapeIO(tape_path)
    for commit in Simuleos.Kernel.iterate_tape(tape)
        commit_count += 1
        scope_count += length(commit.scopes)
        for scope in commit.scopes
            variable_count += length(scope.variables)
            for variable in values(scope.variables)
                if variable isa Simuleos.Kernel.InlineScopeVariable
                    inline_variable_count += 1
                elseif variable isa Simuleos.Kernel.BlobScopeVariable
                    blob_variable_count += 1
                elseif variable isa Simuleos.Kernel.VoidScopeVariable
                    void_variable_count += 1
                end
            end
        end
    end

    return (
        commit_count = commit_count,
        scope_count = scope_count,
        variable_count = variable_count,
        inline_variable_count = inline_variable_count,
        blob_variable_count = blob_variable_count,
        void_variable_count = void_variable_count,
        tape_fragment_count = tape_fragment_count,
        tape_bytes = tape_bytes,
    )
end

function _collect_sessions(project_driver::Simuleos.Kernel.SimuleosProject)::Vector{SessionStats}
    sessions = SessionStats[]
    Simuleos.WorkSession.scan_session_files(project_driver) do raw
        payload = Simuleos.Kernel._string_keys(raw)
        session_id_key = Simuleos.Kernel.SESSION_FILE_ID_KEY
        haskey(payload, session_id_key) || error("Invalid session.json: missing $(session_id_key).")
        session_id = UUIDs.UUID(string(payload[session_id_key]))

        labels = Simuleos.Kernel._session_labels(payload)
        metadata = Simuleos.Kernel._session_meta(payload)
        timestamp_raw = Simuleos.Kernel._session_timestamp(metadata)
        timestamp = timestamp_raw == Dates.DateTime(0) ? nothing : timestamp_raw
        tape_stats = _session_tape_stats(project_driver, session_id)

        push!(sessions, SessionStats(
            session_id,
            labels,
            timestamp,
            tape_stats.commit_count,
            tape_stats.scope_count,
            tape_stats.variable_count,
            tape_stats.inline_variable_count,
            tape_stats.blob_variable_count,
            tape_stats.void_variable_count,
            tape_stats.tape_fragment_count,
            tape_stats.tape_bytes,
        ))
    end
    return sessions
end

function _blobs_stats(project_driver::Simuleos.Kernel.SimuleosProject)::NamedTuple
    dir = Simuleos.Kernel.blobs_dir(project_driver.simuleos_dir)
    isdir(dir) || return (blob_file_count=0, blob_bytes=0)

    files = String[]
    for path in readdir(dir; join=true)
        isfile(path) || continue
        push!(files, path)
    end
    return (blob_file_count=length(files), blob_bytes=_sum_file_sizes(files))
end

function _latest_session(sessions::Vector{SessionStats})::Union{Nothing, SessionStats}
    isempty(sessions) && return nothing

    best = sessions[1]
    best_ts = isnothing(best.timestamp) ? Dates.DateTime(0) : best.timestamp
    for session in sessions[2:end]
        ts = isnothing(session.timestamp) ? Dates.DateTime(0) : session.timestamp
        if ts > best_ts
            best = session
            best_ts = ts
        end
    end
    return best
end

function collect_project_stats(project_path::String)::ProjectStats
    project_driver = Simuleos.project(project_path)
    sessions = _collect_sessions(project_driver)
    blobs_stats = _blobs_stats(project_driver)

    commit_count = 0
    scope_count = 0
    variable_count = 0
    inline_variable_count = 0
    blob_variable_count = 0
    void_variable_count = 0
    tape_fragment_count = 0
    tape_bytes = 0
    for session in sessions
        commit_count += session.commit_count
        scope_count += session.scope_count
        variable_count += session.variable_count
        inline_variable_count += session.inline_variable_count
        blob_variable_count += session.blob_variable_count
        void_variable_count += session.void_variable_count
        tape_fragment_count += session.tape_fragment_count
        tape_bytes += session.tape_bytes
    end

    return ProjectStats(
        Dates.now(),
        project_driver.root_path,
        project_driver.simuleos_dir,
        project_driver.id,
        length(sessions),
        commit_count,
        scope_count,
        variable_count,
        inline_variable_count,
        blob_variable_count,
        void_variable_count,
        tape_fragment_count,
        tape_bytes,
        blobs_stats.blob_file_count,
        blobs_stats.blob_bytes,
        _latest_session(sessions),
    )
end

function _human_bytes(bytes::Int)::String
    if bytes < 1024
        return string(bytes, " B")
    end

    units = ("KiB", "MiB", "GiB", "TiB")
    value = float(bytes)
    unit_idx = 0
    while value >= 1024.0 && unit_idx < length(units)
        value /= 1024.0
        unit_idx += 1
    end
    return Printf.@sprintf("%.1f %s", value, units[unit_idx])
end

function _fmt_timestamp(ts::Union{Nothing, Dates.DateTime})::String
    isnothing(ts) && return "(missing)"
    return string(ts)
end

function _fmt_labels(labels::Vector{String})::String
    isempty(labels) && return "(none)"
    return join(labels, ", ")
end

function render_stats_report(stats::ProjectStats)::String
    lines = String[]
    project_id = isnothing(stats.project_id) ? "(missing)" : string(stats.project_id)
    push!(lines, "Simuleos Project Stats")
    push!(lines, "Generated at: $(stats.generated_at)")
    push!(lines, "")
    push!(lines, "Project")
    push!(lines, "  root: $(stats.project_root)")
    push!(lines, "  simuleos_dir: $(stats.simuleos_dir)")
    push!(lines, "  id: $(project_id)")
    push!(lines, "")
    push!(lines, "Stored Data")
    push!(lines, "  sessions: $(stats.session_count)")
    push!(lines, "  commits: $(stats.commit_count)")
    push!(lines, "  scopes: $(stats.scope_count)")
    push!(lines, "  variables: $(stats.variable_count) (inline=$(stats.inline_variable_count), blob=$(stats.blob_variable_count), void=$(stats.void_variable_count))")
    push!(lines, "  tape fragments: $(stats.tape_fragment_count) ($( _human_bytes(stats.tape_bytes) ))")
    push!(lines, "  blob files: $(stats.blob_file_count) ($( _human_bytes(stats.blob_bytes) ))")
    push!(lines, "")
    if isnothing(stats.latest_session)
        push!(lines, "Latest Session")
        push!(lines, "  (none)")
    else
        latest = stats.latest_session
        push!(lines, "Latest Session")
        push!(lines, "  session_id: $(latest.session_id)")
        push!(lines, "  labels: $(_fmt_labels(latest.labels))")
        push!(lines, "  timestamp: $(_fmt_timestamp(latest.timestamp))")
        push!(lines, "  commits: $(latest.commit_count)")
        push!(lines, "  scopes: $(latest.scope_count)")
        push!(lines, "  variables: $(latest.variable_count)")
    end
    return join(lines, "\n")
end

function stats_command(args::Vector{String}; io::IO = stdout, err_io::IO = stderr)::Int
    project_path = nothing
    try
        project_path = _stats_project_path(args)
    catch err
        println(err_io, "Error: $(sprint(showerror, err))")
        println(err_io, "")
        print_stats_help(err_io)
        return 2
    end

    isnothing(project_path) && (print_stats_help(io); return 0)

    try
        stats = collect_project_stats(project_path)
        println(io, render_stats_report(stats))
        return 0
    catch err
        println(err_io, "Error: $(sprint(showerror, err))")
        return 1
    end
end
