# ============================================================
# tapeio/record.jl — Content-addressed generic record I/O
#
# Provides `record_write` and `record_resolve` for writing
# arbitrary Dict payloads to tape with content-addressed
# RecordRef identifiers.
# ============================================================

import SHA

const RECORD_REF_SHORT_LEN = 12
const RECORD_TYPE_GENERIC = "generic_record"

"""
    record_content_hash(data::AbstractDict) -> String

Compute a deterministic SHA-1 hex hash for a Dict payload.
Keys are sorted recursively before serialization.
"""
function record_content_hash(data::AbstractDict)::String
    json_str = _to_json_string_sorted(data)
    return bytes2hex(SHA.sha1(json_str))
end

"""
    record_ref(data::AbstractDict) -> RecordRef

Build a RecordRef from a Dict payload (hash + short prefix).
"""
function record_ref(data::AbstractDict)::RecordRef
    h = record_content_hash(data)
    short = h[1:min(RECORD_REF_SHORT_LEN, length(h))]
    return RecordRef(h, short)
end

"""
    record_write(tape::TapeIO, data::AbstractDict) -> RecordRef

Write a generic record to tape and return its content-addressed ref.
The record envelope includes `type`, `record_hash`, `record_short`,
`writer`, `timetag`, and `payload`.
"""
function record_write(tape::TapeIO, data::AbstractDict)::RecordRef
    ref = record_ref(data)
    envelope = Dict{String, Any}(
        "type" => RECORD_TYPE_GENERIC,
        "record_hash" => ref.hash,
        "record_short" => ref.short,
        "writer" => "Simuleos",
        "timetag" => string(Dates.now()),
        "payload" => data,
    )
    append!(tape, envelope)
    return ref
end

"""
    record_resolve(tape::TapeIO, ref::RecordRef) -> Union{Dict{String, Any}, Nothing}

Look up a generic record by its RecordRef. Returns the payload dict or nothing.
"""
function record_resolve(tape::TapeIO, ref::RecordRef)::Union{Dict{String, Any}, Nothing}
    return record_resolve(tape, ref.hash)
end

"""
    record_resolve(tape::TapeIO, hash_or_short::String) -> Union{Dict{String, Any}, Nothing}

Look up a generic record by full hash or short prefix. Returns the payload dict or nothing.
"""
function record_resolve(tape::TapeIO, hash_or_short::String)::Union{Dict{String, Any}, Nothing}
    needle = strip(hash_or_short)
    isempty(needle) && return nothing

    record = findfirst_tape_record(tape;
        line_filter = (line, ctx) -> occursin("generic_record", line) && occursin(needle, line),
        json_filter = (obj, ctx) -> begin
            get(obj, "type", "") == RECORD_TYPE_GENERIC || return false
            rh = get(obj, "record_hash", "")
            rs = get(obj, "record_short", "")
            return rh == needle || rs == needle || startswith(rh, needle)
        end,
    )
    isnothing(record) && return nothing
    return get(record, "payload", nothing)
end
