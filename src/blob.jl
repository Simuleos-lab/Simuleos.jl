# Blob storage with SHA1 hashing

using SHA
using Serialization

function _blob_hash(value)::String
    ctx = SHA.SHA1_CTX()
    io = IOBuffer()
    serialize(io, value)
    seekstart(io)
    
    # Read and hash in chunks to reduce memory usage
    chunk_size = 8192
    while !eof(io)
        chunk = read(io, chunk_size)
        SHA.update!(ctx, chunk)
    end
    
    return bytes2hex(SHA.digest!(ctx))
end

function _write_blob(session::Session, value)::String
    hash = _blob_hash(value)
    blob_dir = joinpath(session.root_dir, "blobs")
    mkpath(blob_dir)
    blob_path = joinpath(blob_dir, "$(hash).jls")
    if !isfile(blob_path)
        open(blob_path, "w") do io
            serialize(io, value)
        end
    end
    return hash
end
