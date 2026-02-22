# ============================================================
# blob.jl — Content-addressed blob storage
# ============================================================

import SHA
import Serialization

const BLOB_HASH_CHUNK_SIZE = 8192

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
    return joinpath(storage.blobs_dir, ref.hash * BLOB_EXT)
end

blob_path(storage::BlobStorage, sha1::String)::String = joinpath(storage.blobs_dir, sha1 * BLOB_EXT)

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
Throws if blob already exists and overwrite=false.
"""
function blob_write(storage::BlobStorage, key, value; overwrite::Bool=false)
    ref = blob_ref(key)
    path = _blob_path(storage, ref)
    ensure_dir(dirname(path))

    if isfile(path) && !overwrite
        error("Blob already exists: $(ref.hash). Use overwrite=true to replace.")
    end

    open(path, "w") do io
        Serialization.serialize(io, value)
    end
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
