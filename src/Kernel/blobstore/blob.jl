# Blob storage with SHA1 hashing (all I0x — pure hashing and file I/O)

# Chunk size for streaming hash computation
const HASH_CHUNK_SIZE = 8192

function _blob_hash(value)::String
    ctx = SHA.SHA1_CTX()
    io = IOBuffer()
    Serialization.serialize(io, value)
    seekstart(io)

    # Read and hash in chunks to reduce memory usage
    buffer = Vector{UInt8}(undef, HASH_CHUNK_SIZE)
    while !eof(io)
        n = readbytes!(io, buffer, HASH_CHUNK_SIZE)
        SHA.update!(ctx, view(buffer, 1:n))
    end

    return bytes2hex(SHA.digest!(ctx))
end

function _write_blob(root_dir::String, value)::String
    hash = _blob_hash(value)
    blob_path = _blob_path(root_dir, hash)
    mkpath(dirname(blob_path))
    if !isfile(blob_path)
        open(blob_path, "w") do io
            Serialization.serialize(io, value)
        end
    end
    return hash
end
