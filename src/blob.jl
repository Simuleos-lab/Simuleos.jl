# Blob storage with SHA1 hashing

using SHA
using Serialization

function _blob_hash(value)::String
    io = IOBuffer()
    serialize(io, value)
    bytes = take!(io)
    return bytes2hex(sha1(bytes))
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
