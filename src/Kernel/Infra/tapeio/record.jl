# ============================================================
# tapeio/record.jl — Content-addressed `rec.ref` record I/O
#
# Provides `record_write` and `record_resolve` for writing
# arbitrary Dict payloads to tape with content-addressed
# RecordRef identifiers.
# ============================================================

import SHA

const RECORD_REF_SHORT_LEN = 12

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

Write a `rec.ref` class envelope to tape and return its content-addressed ref.
The envelope includes `record_hash`, `record_short`, `writer`, `timetag`,
and `payload`.
"""
function record_write(tape::TapeIO, data::AbstractDict)::RecordRef
    ref = record_ref(data)
    envelope = RecRefV1(;
        record_hash = ref.hash,
        record_short = ref.short,
        writer = "Simuleos",
        timetag = string(Dates.now()),
        payload = data,
    )
    append!(tape, encode_rec_ref_record(envelope))
    return ref
end

"""
    record_resolve(tape::TapeIO, ref::RecordRef) -> Union{Dict{String, Any}, Nothing}

Look up a `rec.ref` record by its RecordRef. Returns the payload dict or nothing.
"""
function record_resolve(tape::TapeIO, ref::RecordRef)::Union{Dict{String, Any}, Nothing}
    return record_resolve(tape, ref.hash)
end

"""
    record_resolve(tape::TapeIO, hash_or_short::String) -> Union{Dict{String, Any}, Nothing}

Look up a `rec.ref` record by full hash or short prefix. Returns the payload dict or nothing.
"""
function record_resolve(tape::TapeIO, hash_or_short::String)::Union{Dict{String, Any}, Nothing}
    needle = strip(hash_or_short)
    isempty(needle) && return nothing

    record = findfirst_tape_record(tape;
        line_filter = (line, ctx) ->
            occursin("\"$(CLASS_ID_KEY)\":\"$(_REC_REF_CLASS_ID)\"", line) && occursin(needle, line),
        json_filter = (obj, ctx) -> begin
            _record_class_id_value(obj; default = "") == _REC_REF_CLASS_ID || return false
            rh = get(obj, "record_hash", "")
            rs = get(obj, "record_short", "")
            return rh == needle || rs == needle || startswith(rh, needle)
        end,
    )
    isnothing(record) && return nothing
    ref = decode_rec_ref_record(record)
    payload = ref.payload
    payload isa AbstractDict || return nothing
    return _string_keys(payload)
end
