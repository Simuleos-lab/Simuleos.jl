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

function Base.append!(tape::TapeIO, commit::RecCaptureCommitV1)
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

"""
    iterate_tape(tape::TapeIO)

Return the raw tape-record iterator (all records), including tape metadata rows.
Equivalent to iterating the `TapeIO` handle directly.
"""
iterate_tape(tape::TapeIO) = tape

# -- Filtered query helpers (string prefilter -> parse -> JSON filter) --

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

Collect parsed tape records using a two-stage filter:
1. `line_filter(line, ctx)` runs on the stripped JSONL line string (before parsing)
2. `json_filter(obj, ctx)` runs only for lines accepted by `line_filter`

Only records accepted by both filters are returned.
Either callback may call `stop!(ctx)` to stop further scanning. If `json_filter`
returns `true` and also calls `stop!(ctx)`, that accepted record is included and
the scan ends.
"""
function _filtered_tape_files(tape::TapeIO)::Vector{String}
    if _is_fragmented_tape_path(tape.path)
        return _fragment_files(tape.path)
    end
    return isfile(tape.path) ? String[tape.path] : String[]
end

_filtered_tape_files_reverse(tape::TapeIO)::Vector{String} = reverse(_filtered_tape_files(tape))

function _count_file_lines(path::String)::Int
    count = 0
    open(path, "r") do io
        while !eof(io)
            readline(io)
            count += 1
        end
    end
    return count
end

function _file_ends_with_newline(path::String)::Bool
    size = filesize(path)
    size == 0 && return false
    open(path, "r") do io
        seek(io, size - 1)
        return read(io, UInt8) == UInt8('\n')
    end
end

function _scan_reverse_line!(
        stripped::AbstractString,
        file_path::String,
        line_no::Int,
        line_filter::Function,
        json_filter::Function,
        on_record::Function,
        accepted::Int,
    )::Tuple{Int, Bool}
    isempty(stripped) && return accepted, false

    ctx = TapeRecordFilterCtx(file_path, line_no)
    line_ok = line_filter(stripped, ctx)
    if !line_ok
        return accepted, ctx.stop
    end

    local record::Dict{String, Any}
    try
        record = _from_json_string(stripped)
    catch e
        error("Malformed JSON in tape `$(ctx.file)` at line $(ctx.line_no): $(e)")
    end

    if json_filter(record, ctx)
        on_record(record, ctx)
        accepted += 1
    end
    return accepted, ctx.stop
end

function _scan_jsonl_file_reverse!(
        file_path::String;
        line_filter::Function,
        json_filter::Function,
        on_record::Function,
    )::Tuple{Int, Bool}
    isfile(file_path) || return 0, false
    file_size = filesize(file_path)
    file_size == 0 && return 0, false

    total_lines = _count_file_lines(file_path)
    line_no = total_lines
    accepted = 0
    trailing_newline = _file_ends_with_newline(file_path)
    first_segment = true
    carry = UInt8[]

    open(file_path, "r") do io
        pos = file_size
        while pos > 0
            read_size = min(64 * 1024, pos)
            pos -= read_size
            seek(io, pos)
            chunk = read(io, read_size)
            data = isempty(carry) ? chunk : vcat(chunk, carry)

            seg_end = length(data)
            i = seg_end
            while i >= 1
                if data[i] == UInt8('\n')
                    line_bytes = data[(i + 1):seg_end]
                    skip_segment = first_segment && trailing_newline && isempty(line_bytes)
                    first_segment = false
                    if !skip_segment
                        stripped = strip(String(line_bytes))
                        accepted, stop = _scan_reverse_line!(
                            stripped,
                            file_path,
                            line_no,
                            line_filter,
                            json_filter,
                            on_record,
                            accepted,
                        )
                        line_no -= 1
                        stop && return accepted, true
                    end
                    seg_end = i - 1
                end
                i -= 1
            end

            carry = seg_end > 0 ? data[1:seg_end] : UInt8[]
        end
    end

    if !isempty(carry)
        stripped = strip(String(carry))
        accepted, stop = _scan_reverse_line!(
            stripped,
            file_path,
            line_no,
            line_filter,
            json_filter,
            on_record,
            accepted,
        )
        line_no -= 1
        stop && return accepted, true
    end

    return accepted, false
end

"""
    scan_tape_records_filtered(tape::TapeIO; line_filter, json_filter, on_record) -> Int

Scan tape records with line/JSON filters and invoke `on_record(record, ctx)` for
each accepted row. Returns the accepted-row count.
"""
function scan_tape_records_filtered(
        tape::TapeIO;
        line_filter::Function = (line, ctx) -> true,
        json_filter::Function = (obj, ctx) -> true,
        on_record::Function = (record, ctx) -> nothing,
    )::Int
    accepted = 0
    for file_path in _filtered_tape_files(tape)
        open(file_path, "r") do io
            line_no = 0
            while !eof(io)
                line_no += 1
                stripped = strip(readline(io))
                isempty(stripped) && continue

                ctx = TapeRecordFilterCtx(file_path, line_no)
                line_ok = line_filter(stripped, ctx)
                if !line_ok
                    ctx.stop && return accepted
                    continue
                end

                local record::Dict{String, Any}
                try
                    record = _from_json_string(stripped)
                catch e
                    error("Malformed JSON in tape `$(ctx.file)` at line $(ctx.line_no): $(e)")
                end

                if json_filter(record, ctx)
                    on_record(record, ctx)
                    accepted += 1
                end
                ctx.stop && return accepted
            end
        end
    end
    return accepted
end

"""
    scan_tape_records_filtered_reverse(tape::TapeIO; line_filter, json_filter, on_record) -> Int

Same as `scan_tape_records_filtered`, but scans tape records in reverse tape order:
- fragmented tape: `fragN ... frag1`
- each file: last line to first line
"""
function scan_tape_records_filtered_reverse(
        tape::TapeIO;
        line_filter::Function = (line, ctx) -> true,
        json_filter::Function = (obj, ctx) -> true,
        on_record::Function = (record, ctx) -> nothing,
    )::Int
    accepted = 0
    for file_path in _filtered_tape_files_reverse(tape)
        local file_accepted::Int
        local stop::Bool
        file_accepted, stop = _scan_jsonl_file_reverse!(
            file_path;
            line_filter = line_filter,
            json_filter = json_filter,
            on_record = on_record,
        )
        accepted += file_accepted
        stop && return accepted
    end
    return accepted
end

function each_tape_records_filtered(
        tape::TapeIO;
        line_filter::Function = (line, ctx) -> true,
        json_filter::Function = (obj, ctx) -> true,
    )
    rows = Dict{String, Any}[]
    scan_tape_records_filtered(
        tape;
        line_filter = line_filter,
        json_filter = json_filter,
        on_record = (record, ctx) -> push!(rows, record),
    )
    return rows
end

"""
    findfirst_tape_record(tape::TapeIO; line_filter, json_filter) -> Union{Dict{String, Any}, Nothing}

Return the first record accepted by the two-stage filters, or `nothing` if no
match is found.

This helper calls `stop!(ctx)` internally on the first accepted record.
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
    rows = each_tape_records_filtered(tape; line_filter=line_filter, json_filter=wrapped_json_filter)
    isempty(rows) || (found = rows[1])
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
match is found. Scans in reverse tape order and stops at the first accepted
record.
"""
function findlast_tape_record(
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
    scan_tape_records_filtered_reverse(
        tape;
        line_filter = line_filter,
        json_filter = wrapped_json_filter,
        on_record = (record, ctx) -> (found = record),
    )
    return found
end

_normalize_tape_fetch_limit(limit::Nothing) = nothing
function _normalize_tape_fetch_limit(limit::Integer)
    limit > 0 || error("Expected `limit > 0`, got `$(limit)`.")
    return Int(limit)
end

"""
    each_tape_records(tape::TapeIO; line_filter, json_filter, on_record, reverse=false) -> Int

Agnostic callback-based record scan.

- `line_filter(line, ctx)`: pre-JSON filter
- `json_filter(record, ctx)`: parsed-record filter
- `on_record(record, ctx)`: callback for accepted records

Returns accepted-record count.
"""
function each_tape_records(
        tape::TapeIO;
        line_filter::Function = (line, ctx) -> true,
        json_filter::Function = (obj, ctx) -> true,
        on_record::Function = (record, ctx) -> nothing,
        reverse::Bool = false,
    )::Int
    scanner = reverse ? scan_tape_records_filtered_reverse : scan_tape_records_filtered
    return scanner(
        tape;
        line_filter = line_filter,
        json_filter = json_filter,
        on_record = on_record,
    )
end

"""
    fetch_tape_records(tape::TapeIO; line_filter, json_filter, reverse=false, limit=nothing) -> Vector{Dict{String, Any}}

Materialize accepted records from `each_tape_records`.
"""
function fetch_tape_records(
        tape::TapeIO;
        line_filter::Function = (line, ctx) -> true,
        json_filter::Function = (obj, ctx) -> true,
        reverse::Bool = false,
        limit::Union{Nothing, Integer} = nothing,
    )::Vector{Dict{String, Any}}
    max_rows = _normalize_tape_fetch_limit(limit)
    rows = Dict{String, Any}[]
    each_tape_records(
        tape;
        line_filter = line_filter,
        json_filter = json_filter,
        reverse = reverse,
        on_record = function (record, ctx)
            push!(rows, record)
            !isnothing(max_rows) && length(rows) >= max_rows && stop!(ctx)
            return nothing
        end,
    )
    return rows
end

"""
    find_tape_records(tape::TapeIO; line_filter, json_filter, reverse=false, limit=nothing) -> Vector{Dict{String, Any}}

Agnostic finder alias over `fetch_tape_records`.
"""
function find_tape_records(
        tape::TapeIO;
        line_filter::Function = (line, ctx) -> true,
        json_filter::Function = (obj, ctx) -> true,
        reverse::Bool = false,
        limit::Union{Nothing, Integer} = nothing,
    )::Vector{Dict{String, Any}}
    return fetch_tape_records(
        tape;
        line_filter = line_filter,
        json_filter = json_filter,
        reverse = reverse,
        limit = limit,
    )
end

"""
    latest_tape_record(tape::TapeIO; line_filter, json_filter) -> Union{Dict{String, Any}, Nothing}

Return the latest matching record in tape order.
"""
function latest_tape_record(
        tape::TapeIO;
        line_filter::Function = (line, ctx) -> true,
        json_filter::Function = (obj, ctx) -> true,
    )::Union{Dict{String, Any}, Nothing}
    return findlast_tape_record(
        tape;
        line_filter = line_filter,
        json_filter = json_filter,
    )
end

"""
    table_tape_records(tape::TapeIO; line_filter, json_filter, row_builder, reverse=false, limit=nothing) -> Vector

Map accepted tape records to table rows via `row_builder(record, ctx)`.
"""
function table_tape_records(
        tape::TapeIO;
        line_filter::Function = (line, ctx) -> true,
        json_filter::Function = (obj, ctx) -> true,
        row_builder::Function = (record, ctx) -> record,
        reverse::Bool = false,
        limit::Union{Nothing, Integer} = nothing,
    )::Vector
    max_rows = _normalize_tape_fetch_limit(limit)
    rows = Any[]
    each_tape_records(
        tape;
        line_filter = line_filter,
        json_filter = json_filter,
        reverse = reverse,
        on_record = function (record, ctx)
            push!(rows, row_builder(record, ctx))
            !isnothing(max_rows) && length(rows) >= max_rows && stop!(ctx)
            return nothing
        end,
    )
    return rows
end
