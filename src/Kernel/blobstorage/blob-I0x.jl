# BlobStorage subsystem (all I0x)
# Stores arbitrary Julia values in blobs/<sha1>.jls where sha1 is derived from the key.

const BLOB_HASH_CHUNK_SIZE = 8192

function _hash_key(key)::String
    ctx = SHA.SHA1_CTX()
    io = IOBuffer()
    Serialization.serialize(io, key)
    seekstart(io)

    buffer = Vector{UInt8}(undef, BLOB_HASH_CHUNK_SIZE)
    while !eof(io)
        n = readbytes!(io, buffer, BLOB_HASH_CHUNK_SIZE)
        SHA.update!(ctx, view(buffer, 1:n))
    end

    return bytes2hex(SHA.digest!(ctx))
end

function _serialize_bytes(value)::Vector{UInt8}
    io = IOBuffer()
    Serialization.serialize(io, value)
    take!(io)
end

function blob_ref(key)::BlobRef
    BlobRef(_hash_key(key))
end

function exists(root_dir::String, ref::BlobRef)
    isfile(_blob_path(root_dir, ref.hash))
end

function exists(root_dir::String, key)
    exists(root_dir, blob_ref(key))
end

function blob_write(
        root_dir::String, 
        key, value; 
        overwrite::Bool=false
    )::BlobRef
    ref = blob_ref(key)
    path = _blob_path(root_dir, ref.hash)
    mkpath(dirname(path))

    serialized_value = _serialize_bytes(value)

    if isfile(path)
        if !overwrite
            existing = read(path)
            existing == serialized_value || error(
                "Blob already exists for key-hash $(ref.hash), and stored value differs. " *
                "Use overwrite=true to replace it."
            )
            return ref
        end
    end

    open(path, "w") do io
        write(io, serialized_value)
    end
    return ref
end

function blob_read(root_dir::String, ref::BlobRef)
    path = _blob_path(root_dir, ref.hash)
    isfile(path) || error("Blob not found for hash $(ref.hash): $path")
    open(path, "r") do io
        Serialization.deserialize(io)
    end
end

function blob_read(root_dir::String, key)
    blob_read(root_dir, blob_ref(key))
end
