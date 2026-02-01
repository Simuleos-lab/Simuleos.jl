## .-.- -. ... .,.-. - ,-. . ,., .,,.;; .- .-
# Utils for handling files
# - loading/writing/appending etc

## .-.- -. ... .,.-. - ,-. . ,., .,,.;; .- .-
# Allocate less
function _eachline_bytes_v2(
        fun::Function, 
        path::AbstractString; 
        keep::Bool=true
    )

    open(path, "r") do io

        duff_size = 1024 * 1024
        read_buff = Vector{UInt8}(undef, duff_size)
        line_buff = Vector{UInt8}(undef, duff_size)
        
        b = UInt8(0)
        cursor = 0

        while !eof(io)
            n = readbytes!(io, read_buff)  # read up to BUFSIZE bytes
            i = 0
            while true
                
                i += 1
                i > n && break

                b = read_buff[i]
                cursor += 1

                # extend
                if cursor > length(line_buff)
                    nexsize = max(
                        ceil(Int, length(line_buff) * 1.5), 
                        cursor
                    )
                    resize!(line_buff, nexsize)
                end
                line_buff[cursor] = b

                # 0x0a is '\n'
                if b == 0x0a
                    if !keep
                        cursor = max(1, cursor-1)
                    end
                    buff_view = view(line_buff, 1:cursor)
                    ret = fun(buff_view)
                    ret == :break && return
                    cursor = 0
                end
            end
        end # while !eof(io)
    end
end

# This version allocates
function _eachline_bytes_v1(
        fun::Function, 
        path::AbstractString; 
        keep::Bool=true
    )
    open(path, "r") do io
        while !eof(io)
            # 0x0a is '\n'
            linebytes = readuntil(io, 0x0a; keep)
            ret = fun(linebytes)
            ret === :break && break
        end
    end
end

function eachline_bytes(path::AbstractString; 
        keep::Bool=true
    )
    return Channel{Vector{UInt8}}(10) do _ch
        eachline_bytes(path; keep) do linebytes
            put!(_ch, linebytes)
        end
    end
end

function eachline_bytes(
        fun::Function, 
        path::AbstractString; 
        keep::Bool=true
    )
    _eachline_bytes_v1(fun, path; keep)
end
