# ============================================================
# tape.jl — TapeIO: JSONL operations (single file or fragmented directory)
# ============================================================

const TAPE_SIZE_WARN_MB = 200
const MAX_TAPE_SIZE_BYTES = 200_000_000
const FRAGMENT_FILENAME_RE = r"^frag(\d+)\.jsonl$"
const TAPE_METADATA_TYPE = "tape_metadata"

function _is_fragmented_tape_path(path::String)::Bool
    return isdir(path) || !endswith(lowercase(path), ".jsonl")
end

function _fragment_index(path_or_name::String)::Union{Int, Nothing}
    name = basename(path_or_name)
    m = match(FRAGMENT_FILENAME_RE, name)
    isnothing(m) && return nothing
    return parse(Int, m.captures[1])
end

_fragment_filename(idx::Int)::String = "frag$(idx).jsonl"

function _fragment_files(tape_dir::String)::Vector{String}
    isdir(tape_dir) || return String[]

    files = String[]
    for entry in readdir(tape_dir)
        isnothing(_fragment_index(entry)) && continue
        push!(files, joinpath(tape_dir, entry))
    end
    sort!(files; by = p -> _fragment_index(p))
    return files
end

function _latest_fragment_path(tape_dir::String)::String
    files = _fragment_files(tape_dir)
    isempty(files) && return joinpath(tape_dir, _fragment_filename(1))
    return files[end]
end

function _next_fragment_path(tape_dir::String)::String
    files = _fragment_files(tape_dir)
    if isempty(files)
        return joinpath(tape_dir, _fragment_filename(1))
    end
    last_idx = _fragment_index(files[end])
    isnothing(last_idx) && return joinpath(tape_dir, _fragment_filename(length(files) + 1))
    return joinpath(tape_dir, _fragment_filename(last_idx + 1))
end

function _append_target_path(tape::TapeIO)::String
    if _is_fragmented_tape_path(tape.path)
        ensure_dir(tape.path)
        current = _latest_fragment_path(tape.path)
        if isfile(current) && filesize(current) >= MAX_TAPE_SIZE_BYTES
            return _next_fragment_path(tape.path)
        end
        return current
    end
    ensure_dir(dirname(tape.path))
    return tape.path
end

function _is_tape_metadata_record(record::AbstractDict)::Bool
    return get(record, "type", get(record, :type, "")) == TAPE_METADATA_TYPE
end

function _tape_name(tape::TapeIO)::String
    if _is_fragmented_tape_path(tape.path)
        return basename(normpath(tape.path))
    end
    name = basename(tape.path)
    endswith(lowercase(name), ".jsonl") && return splitext(name)[1]
    return name
end

function _tape_has_any_record(tape::TapeIO)::Bool
    if _is_fragmented_tape_path(tape.path)
        for file in _fragment_files(tape.path)
            isfile(file) || continue
            filesize(file) > 0 && return true
        end
        return false
    end
    return isfile(tape.path) && filesize(tape.path) > 0
end

function _tape_metadata_record(tape::TapeIO)::Dict{String, Any}
    return Dict{String, Any}(
        "type" => TAPE_METADATA_TYPE,
        "tape_name" => _tape_name(tape),
        "created_at" => string(Dates.now()),
        "format" => "jsonl",
        "storage_mode" => _is_fragmented_tape_path(tape.path) ? "fragmented" : "single_file",
        "fragment_pattern" => _is_fragmented_tape_path(tape.path) ? "fragN.jsonl" : "",
        "writer" => "Simuleos",
    )
end

function _append_json_line!(path::String, value)
    open(path, "a") do io
        _write_json(io, value)
        write(io, '\n')
    end
    return nothing
end

function _ensure_tape_metadata!(tape::TapeIO, target::String)
    _tape_has_any_record(tape) && return nothing
    _append_json_line!(target, _tape_metadata_record(tape))
    return nothing
end

"""
    append!(tape::TapeIO, record::AbstractDict)

Append a single record (as one JSON line) to a tape.
If `tape.path` points to a directory, appends to fragmented files:
`frag1.jsonl`, `frag2.jsonl`, ...
"""
function Base.append!(tape::TapeIO, record::AbstractDict)
    target = _append_target_path(tape)
    !_is_tape_metadata_record(record) && _ensure_tape_metadata!(tape, target)
    _append_json_line!(target, record)
    _check_tape_size(target)
    return tape
end

function Base.append!(tape::TapeIO, commit::ScopeCommit)
    target = _append_target_path(tape)
    _ensure_tape_metadata!(tape, target)
    _append_json_line!(target, commit)
    _check_tape_size(target)
    return tape
end

"""Check tape file size and warn if large."""
function _check_tape_size(path::String)
    isfile(path) || return
    sz_mb = filesize(path) / (1024 * 1024)
    if sz_mb > TAPE_SIZE_WARN_MB
        @warn "Tape fragment is $(round(sz_mb; digits=1)) MB: $(path)"
    end
end

# -- Iteration protocol for raw records --

"""
    Base.iterate(tape::TapeIO)

Iterate over raw Dict records in a tape:
- single JSONL file, or
- fragmented tape directory with `fragN.jsonl` files.
"""
function Base.iterate(tape::TapeIO)
    if _is_fragmented_tape_path(tape.path)
        files = _fragment_files(tape.path)
        isempty(files) && return nothing
        state = (files = files, file_idx = 1, io = open(files[1], "r"))
        return _tape_next_fragment(state)
    end

    isfile(tape.path) || return nothing
    io = open(tape.path, "r")
    return _tape_next_file(io, tape.path)
end

function Base.iterate(tape::TapeIO, state)
    if _is_fragmented_tape_path(tape.path)
        return _tape_next_fragment(state)
    end
    return _tape_next_file(state, tape.path)
end

function _tape_next_file(io::IO, source_path::String)
    while !eof(io)
        line = readline(io)
        stripped = strip(line)
        isempty(stripped) && continue
        try
            record = _from_json_string(stripped)
            return (record, io)
        catch e
            close(io)
            error("Malformed JSON in tape `$(source_path)`: $(e)")
        end
    end
    close(io)
    return nothing
end

function _tape_next_fragment(state)
    files = state.files
    file_idx = state.file_idx
    io = state.io

    while true
        result = _tape_next_file(io, files[file_idx])
        if !isnothing(result)
            (record, io_after) = result
            return (record, (files = files, file_idx = file_idx, io = io_after))
        end

        file_idx += 1
        file_idx > length(files) && return nothing
        io = open(files[file_idx], "r")
    end
end

Base.IteratorSize(::Type{TapeIO}) = Base.SizeUnknown()
Base.eltype(::Type{TapeIO}) = Dict{String, Any}

"""
    Base.collect(tape::TapeIO) -> Vector{Dict{String, Any}}

Collect all records from a tape into a vector.
"""
function Base.collect(tape::TapeIO)
    records = Dict{String, Any}[]
    for record in tape
        push!(records, record)
    end
    return records
end

# -- Lazy filtered iteration (string prefilter -> parse -> JSON filter) --

"""
    TapeRecordFilterCtx

Mutable context passed to `each_tape_records_filtered` callbacks.
Fields are updated per line candidate:
- `file`: source tape fragment/file path
- `line_no`: 1-based physical line number within that file
- `stop`: set via `stop!(ctx)` to halt scanning after the current callback stage
"""
mutable struct TapeRecordFilterCtx
    file::String
    line_no::Int
    stop::Bool
end

TapeRecordFilterCtx(file::String, line_no::Int) = TapeRecordFilterCtx(file, line_no, false)

"""Request `each_tape_records_filtered` to stop scanning after the current callback stage."""
function stop!(ctx::TapeRecordFilterCtx)
    ctx.stop = true
    return nothing
end

"""
    each_tape_records_filtered(tape::TapeIO; line_filter, json_filter)

Lazily iterate parsed tape records using a two-stage filter:
1. `line_filter(line, ctx)` runs on the stripped JSONL line string (before parsing)
2. `json_filter(obj, ctx)` runs only for lines accepted by `line_filter`

Only records accepted by both filters are yielded.
Either callback may call `stop!(ctx)` to stop further scanning. If `json_filter`
returns `true` and also calls `stop!(ctx)`, the current record is yielded and
iteration ends on the next step.
"""
struct FilteredTapeRecordIterator
    tape::TapeIO
    line_filter::Function
    json_filter::Function
end

function each_tape_records_filtered(
        tape::TapeIO;
        line_filter::Function = (line, ctx) -> true,
        json_filter::Function = (obj, ctx) -> true,
    )
    return FilteredTapeRecordIterator(tape, line_filter, json_filter)
end

mutable struct _FilteredTapeRecordState
    files::Vector{String}
    file_idx::Int
    io::Union{Nothing, IO}
    line_no::Int
    stop::Bool
end

function _filtered_tape_files(tape::TapeIO)::Vector{String}
    if _is_fragmented_tape_path(tape.path)
        return _fragment_files(tape.path)
    end
    return isfile(tape.path) ? String[tape.path] : String[]
end

function _filtered_tape_close!(state::_FilteredTapeRecordState)
    if !isnothing(state.io)
        close(state.io)
        state.io = nothing
    end
    return nothing
end

function _filtered_tape_open_current!(state::_FilteredTapeRecordState)::Bool
    state.file_idx > length(state.files) && return false
    state.io = open(state.files[state.file_idx], "r")
    state.line_no = 0
    return true
end

function _filtered_tape_finish!(state::_FilteredTapeRecordState)
    _filtered_tape_close!(state)
    return nothing
end

function _filtered_tape_next(it::FilteredTapeRecordIterator, state::_FilteredTapeRecordState)
    state.stop && (_filtered_tape_finish!(state); return nothing)

    while true
        io = state.io
        isnothing(io) && return nothing

        while !eof(io)
            line = readline(io)
            state.line_no += 1
            stripped = strip(line)
            isempty(stripped) && continue

            ctx = TapeRecordFilterCtx(state.files[state.file_idx], state.line_no)

            line_ok = it.line_filter(stripped, ctx)
            ctx.stop && (state.stop = true)
            if !line_ok
                state.stop && (_filtered_tape_finish!(state); return nothing)
                continue
            end

            local record::Dict{String, Any}
            try
                record = _from_json_string(stripped)
            catch e
                _filtered_tape_finish!(state)
                error("Malformed JSON in tape `$(ctx.file)` at line $(ctx.line_no): $(e)")
            end

            json_ok = it.json_filter(record, ctx)
            ctx.stop && (state.stop = true)

            if json_ok
                return (record, state)
            end

            state.stop && (_filtered_tape_finish!(state); return nothing)
        end

        _filtered_tape_close!(state)
        state.file_idx += 1
        state.file_idx > length(state.files) && return nothing
        _filtered_tape_open_current!(state) || return nothing
    end
end

function Base.iterate(it::FilteredTapeRecordIterator)
    files = _filtered_tape_files(it.tape)
    isempty(files) && return nothing

    state = _FilteredTapeRecordState(files, 1, nothing, 0, false)
    _filtered_tape_open_current!(state) || return nothing
    return _filtered_tape_next(it, state)
end

function Base.iterate(it::FilteredTapeRecordIterator, state::_FilteredTapeRecordState)
    return _filtered_tape_next(it, state)
end

Base.IteratorSize(::Type{FilteredTapeRecordIterator}) = Base.SizeUnknown()
Base.eltype(::Type{FilteredTapeRecordIterator}) = Dict{String, Any}

"""
    findfirst_tape_record(tape::TapeIO; line_filter, json_filter) -> Union{Dict{String, Any}, Nothing}

Return the first record accepted by the two-stage filters, or `nothing` if no
match is found.

This helper calls `stop!(ctx)` internally on the first accepted record so the
underlying filtered iterator can close resources cleanly without requiring the
caller to manage `ctx.stop`.
"""
function findfirst_tape_record(
        tape::TapeIO;
        line_filter::Function = (line, ctx) -> true,
        json_filter::Function = (obj, ctx) -> true,
    )
    found = nothing
    wrapped_json_filter = function (obj, ctx)
        ok = json_filter(obj, ctx)
        ok && stop!(ctx)
        return ok
    end
    for record in each_tape_records_filtered(tape; line_filter=line_filter, json_filter=wrapped_json_filter)
        found = record
    end
    return found
end

"""
    any_tape_record(tape::TapeIO; line_filter, json_filter) -> Bool

Return `true` if any record matches the two-stage filters.
"""
function any_tape_record(
        tape::TapeIO;
        line_filter::Function = (line, ctx) -> true,
        json_filter::Function = (obj, ctx) -> true,
    )::Bool
    return !isnothing(findfirst_tape_record(
        tape;
        line_filter = line_filter,
        json_filter = json_filter,
    ))
end

"""
    findlast_tape_record(tape::TapeIO; line_filter, json_filter) -> Union{Dict{String, Any}, Nothing}

Return the last record accepted by the two-stage filters, or `nothing` if no
match is found. This performs a full scan in tape order.
"""
function findlast_tape_record(
        tape::TapeIO;
        line_filter::Function = (line, ctx) -> true,
        json_filter::Function = (obj, ctx) -> true,
    )
    found = nothing
    for record in each_tape_records_filtered(tape; line_filter=line_filter, json_filter=json_filter)
        found = record
    end
    return found
end
