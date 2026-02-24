# ============================================================
# blob.jl — Content-addressed blob storage
# ============================================================

import SHA
import Serialization

const _BLOB_RECORD_TYPE = "blob_record"
const _BLOB_RECORD_SCHEMA_V1 = "blob_record_v1"
const _BLOB_SERIALIZER_ID = "julia/Serialization"
const _BLOB_FORMAT_ID = "jls"
const _BLOB_PAYLOAD_HASH_ALG = "sha1"

struct BlobAlreadyExistsError <: Exception
    ref::BlobRef
    path::String
end

function Base.showerror(io::IO, err::BlobAlreadyExistsError)
    print(io, "Blob already exists: ", err.ref.hash, ". Use overwrite=true to replace.")
end

"""
    blob_ref(key) -> BlobRef

Compute a BlobRef (SHA-1 hash) for the given key.
The key is serialized to bytes, then hashed.
"""
function blob_ref(key)
    io = IOBuffer()
    Serialization.serialize(io, key)
    hash = SHA.sha1(take!(io)) |> bytes2hex
    return BlobRef(hash)
end

"""
    _blob_path(storage::BlobStorage, ref::BlobRef) -> String

Full filesystem path for a blob.
"""
function _blob_path(storage::BlobStorage, ref::BlobRef)
    return blob_path(storage, ref.hash)
end

blob_path(storage::BlobStorage, sha1::String)::String = joinpath(blobs_dir(storage), sha1 * BLOB_EXT)

function _blob_payload_sha1(path::String)::String
    return open(path, "r") do io
        SHA.sha1(io) |> bytes2hex
    end
end

function _blob_tape_record(
        storage::BlobStorage,
        ref::BlobRef,
        path::String;
        replaced_existing::Bool,
    )::Dict{String, Any}
    rel = relpath(path, blobs_dir(storage))
    return Dict{String, Any}(
        "type" => _BLOB_RECORD_TYPE,
        "schema" => _BLOB_RECORD_SCHEMA_V1,
        "blob_hash" => ref.hash,
        "hash_prefix" => _blob_tape_shard_prefix(ref.hash),
        "blob_relpath" => rel,
        "blob_ext" => BLOB_EXT,
        "serializer" => _BLOB_SERIALIZER_ID,
        "format" => _BLOB_FORMAT_ID,
        "payload_hash_alg" => _BLOB_PAYLOAD_HASH_ALG,
        "payload_hash" => _blob_payload_sha1(path),
        "byte_size" => filesize(path),
        "replaced_existing" => replaced_existing,
        "created_at" => string(Dates.now()),
    )
end

function _blob_tape_append!(storage::BlobStorage, ref::BlobRef, path::String; replaced_existing::Bool)::Nothing
    shard_tape = TapeIO(blob_tape_shard_path(storage, ref))
    record = _blob_tape_record(storage, ref, path; replaced_existing = replaced_existing)
    append!(shard_tape, record)
    return nothing
end

function _blob_hash_from_filename(filename::AbstractString)::Union{String, Nothing}
    name = basename(String(filename))
    endswith(name, BLOB_EXT) || return nothing
    hash = name[1:(end - lastindex(BLOB_EXT))]
    isempty(hash) && return nothing
    return hash
end

function _blob_tape_indexed_hashes(storage::BlobStorage, shard_prefix::AbstractString)::Set{String}
    shard_path = blob_tape_shard_path_for_prefix(storage, shard_prefix)
    isfile(shard_path) || return Set{String}()

    hashes = Set{String}()
    for row in each_tape_records_filtered(
            TapeIO(shard_path);
            line_filter = (line, ctx) -> occursin("\"type\":\"$(_BLOB_RECORD_TYPE)\"", line),
            json_filter = (row, ctx) -> get(row, "type", "") == _BLOB_RECORD_TYPE,
        )
        record_hash = _blob_record_hash_from_row(row)
        isnothing(record_hash) && continue
        push!(hashes, record_hash)
    end
    return hashes
end

function _blob_record_hash_from_row(row)::Union{String, Nothing}
    get(row, "type", "") == _BLOB_RECORD_TYPE || return nothing
    raw_hash = get(row, "blob_hash", nothing)
    raw_hash isa AbstractString || return nothing
    return lowercase(String(raw_hash))
end

function _blob_meta_lookup_ref(key_or_ref)::BlobRef
    if key_or_ref isa BlobRef
        return key_or_ref
    end

    if key_or_ref isa AbstractString
        s = strip(String(key_or_ref))
        if occursin(r"^[0-9a-fA-F]{40}$", s)
            return BlobRef(lowercase(s))
        end
    end

    return blob_ref(key_or_ref)
end

"""
    blob_metadata(storage::BlobStorage, key_or_ref) -> Union{Dict{String, Any}, Nothing}

Return the latest blob metadata record from the blob shard tape, or `nothing`
if no record is found.

Accepted lookup forms:
- `BlobRef`
- 40-char hex hash string
- any other value (treated as a blob key and hashed with `blob_ref`)
"""
function blob_metadata(storage::BlobStorage, key_or_ref)
    ref = _blob_meta_lookup_ref(key_or_ref)
    shard_path = blob_tape_shard_path(storage, ref)
    isfile(shard_path) || return nothing

    target_hash = lowercase(ref.hash)
    return findlast_tape_record(
        TapeIO(shard_path);
        line_filter = (line, ctx) ->
            occursin("\"type\":\"$(_BLOB_RECORD_TYPE)\"", line) &&
            occursin(target_hash, line),
        json_filter = (row, ctx) -> _blob_record_hash_from_row(row) == target_hash,
    )
end

blob_metadata(proj::SimuleosProject, key_or_ref) = blob_metadata(proj.blobstorage, key_or_ref)
blob_metadata(simos::SimOs, key_or_ref) = blob_metadata(sim_project(simos).blobstorage, key_or_ref)

"""
    blob_metadata_indexed(storage::BlobStorage, key_or_ref) -> Bool

Return `true` if the blob metadata shard tape contains at least one `blob_record`
for the resolved hash.

This checks metadata tape indexing (JSONL shard), not payload-file existence.

Accepted lookup forms:
- `BlobRef`
- 40-char hex hash string
- any other value (treated as a blob key and hashed with `blob_ref`)
"""
function blob_metadata_indexed(storage::BlobStorage, key_or_ref)::Bool
    ref = _blob_meta_lookup_ref(key_or_ref)
    shard_path = blob_tape_shard_path(storage, ref)
    isfile(shard_path) || return false

    target_hash = lowercase(ref.hash)
    return any_tape_record(
        TapeIO(shard_path);
        line_filter = (line, ctx) ->
            occursin("\"type\":\"$(_BLOB_RECORD_TYPE)\"", line) &&
            occursin(target_hash, line),
        json_filter = (row, ctx) -> _blob_record_hash_from_row(row) == target_hash,
    )
end

blob_metadata_indexed(proj::SimuleosProject, key_or_ref) = blob_metadata_indexed(proj.blobstorage, key_or_ref)
blob_metadata_indexed(simos::SimOs, key_or_ref) = blob_metadata_indexed(sim_project(simos).blobstorage, key_or_ref)

"""
    blob_tapes_backfill!(storage::BlobStorage) -> NamedTuple

Scan `.simuleos/blobs/*.jls` and append missing `blob_record` entries into
`blobs/tapes/<hh>.jsonl` shard tapes, where `<hh>` is the first two chars of
the blob hash.

This is a repair/backfill utility: it only appends records for blob hashes not
already present in the corresponding shard tape.
"""
function blob_tapes_backfill!(storage::BlobStorage)
    isdir(blobs_dir(storage)) || return (
        scanned_blobs = 0,
        appended_records = 0,
        skipped_existing = 0,
        shards_loaded = 0,
        shards_written = 0,
    )

    blob_paths = String[]
    for entry in readdir(blobs_dir(storage); join = true)
        isfile(entry) || continue
        isnothing(_blob_hash_from_filename(entry)) && continue
        push!(blob_paths, entry)
    end
    sort!(blob_paths)

    indexed_by_shard = Dict{String, Set{String}}()
    shards_loaded = 0
    shards_written = Set{String}()
    appended_records = 0
    skipped_existing = 0

    for path in blob_paths
        hash = _blob_hash_from_filename(path)
        isnothing(hash) && continue
        hash_s = lowercase(hash)
        shard = _blob_tape_shard_prefix(hash_s)

        if !haskey(indexed_by_shard, shard)
            indexed_by_shard[shard] = _blob_tape_indexed_hashes(storage, shard)
            shards_loaded += 1
        end

        if hash_s in indexed_by_shard[shard]
            skipped_existing += 1
            continue
        end

        ref = BlobRef(hash_s)
        _blob_tape_append!(storage, ref, path; replaced_existing = false)
        push!(indexed_by_shard[shard], hash_s)
        push!(shards_written, shard)
        appended_records += 1
    end

    return (
        scanned_blobs = length(blob_paths),
        appended_records = appended_records,
        skipped_existing = skipped_existing,
        shards_loaded = shards_loaded,
        shards_written = length(shards_written),
    )
end

blob_tapes_backfill!(proj::SimuleosProject) = blob_tapes_backfill!(proj.blobstorage)
blob_tapes_backfill!(simos::SimOs) = blob_tapes_backfill!(sim_project(simos).blobstorage)

"""
    exists(storage::BlobStorage, ref::BlobRef) -> Bool

Check if a blob exists in storage.
"""
function exists(storage::BlobStorage, ref::BlobRef)
    return isfile(_blob_path(storage, ref))
end

"""
    exists(storage::BlobStorage, key) -> Bool

Check if a blob for the given key exists in storage.
"""
exists(storage::BlobStorage, key) = exists(storage, blob_ref(key))

"""
    blob_write(storage::BlobStorage, key, value; overwrite=false) -> BlobRef

Write a value to blob storage. Returns the BlobRef.
Throws `BlobAlreadyExistsError` if blob already exists and `overwrite=false`.
"""
function blob_write(storage::BlobStorage, key, value; overwrite::Bool=false)
    ref = blob_ref(key)
    path = _blob_path(storage, ref)
    ensure_dir(dirname(path))

    replaced_existing = isfile(path)
    if replaced_existing && !overwrite
        throw(BlobAlreadyExistsError(ref, path))
    end

    open(path, "w") do io
        Serialization.serialize(io, value)
    end

    # Write blob payload first; metadata tape is a secondary index and is updated after.
    _blob_tape_append!(storage, ref, path; replaced_existing = replaced_existing)
    return ref
end

"""
    blob_read(storage::BlobStorage, ref::BlobRef) -> Any

Read and deserialize a blob.
"""
function blob_read(storage::BlobStorage, ref::BlobRef)
    path = _blob_path(storage, ref)
    isfile(path) || error("Blob not found: $(ref.hash)")
    return open(path, "r") do io
        Serialization.deserialize(io)
    end
end

"""
    blob_read(storage::BlobStorage, key) -> Any

Read a blob by computing its ref from the key.
"""
blob_read(storage::BlobStorage, key) = blob_read(storage, blob_ref(key))

# -- SimOs convenience wrappers --

"""Write a blob through the global SimOs project."""
function blob_write(simos::SimOs, key, value; kw...)
    blob_write(sim_project(simos).blobstorage, key, value; kw...)
end

"""Read a blob through the global SimOs project."""
function blob_read(simos::SimOs, key)
    storage = sim_project(simos).blobstorage
    if key isa BlobRef
        blob_read(storage, key)
    else
        blob_read(storage, key)
    end
end
