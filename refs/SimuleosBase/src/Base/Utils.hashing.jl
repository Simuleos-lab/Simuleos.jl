
## .-.- -. ... .,.-. - ,-. . ,., .,,.;; .- .-
# MARK: SHA265

# TODO/CONST: Always try to optimize this...
function sha256_str(str::AbstractString)
    ctx = SHA.SHA256_CTX()   # initialize SHA256 state
    SHA.update!(ctx, codeunits(str))      # update hash with this byte
    return bytes2hex(SHA.digest!(ctx))   # finalize and return hash as Vector{UInt8}
end

function sha256_iolines(io::IOStream; 
        buff_size = 4096 # KiB
    )
    ctx = SHA.SHA256_CTX()
    buf = Vector{UInt8}(undef, buff_size)  # 4 KiB buffer
    while true
        nread = readbytes!(io, buf)   # <= returns 0 at EOF, no error
        nread == 0 && break
        SHA.update!(ctx, view(buf, 1:nread))
    end
    digest = SHA.digest!(ctx)
    return bytes2hex(digest)
end

function sha256_file(filename::AbstractString; 
        buff_size = 4096 # KiB
    )
    hash::String = ""
    open(filename, "r") do io
        hash = sha256_iolines(io; buff_size)
    end
    return hash
end
