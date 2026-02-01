## --.--. - .-. .- .--.-.- .- .---- ... . .-.-.-.- 
function _show_bbBlobs(io, bb::BlobBatch)
    # depot frames
    frames_kTv = Dict()
    _push_frames_kTv!(frames_kTv, bb) do k
        k isa String && return true
        return false
    end
    if !isempty(frames_kTv)
        print(io, "\n\nDepot bb blobs: \n")
        _print_frames_kTv(io, frames_kTv)
    end
end

function _show_bBlobs(io, bb::BlobBatch; npeek = 100)
    # depot frames
    frames_kTv = Dict()
    bch = eachblob(bb)
    for (bi, b) in enumerate(bch)
        _push_frames_kTv!(frames_kTv, b) do k
            k isa String && return true
            return false
        end
        bi >= npeek && break
    end
    if !isempty(frames_kTv)
        print(io, "\n\nDepot b blobs: \n")
        _print_frames_kTv(io, frames_kTv)
    end
end


## --.--. - .-. .- .--.-.- .- .---- ... . .-.-.-.- 
import Base.show
function Base.show(io::IO, bb::BlobBatch)
    print(io, "BlobBatch(", repr(bb.id), ")")
    _pretty_print_pairs(io, 
        "\n filesys", 
        string("@./", basename(batchpath(bb)))
    )
    _pretty_print_pairs(io, 
        "\n vblob(s)", blobcount(bb)
    )

    # bb Blobs
    _show_bbBlobs(io, bb)
    
    # b Blobs
    _show_bBlobs(io, bb)

    # disk
    _show_disk_files(io, batchpath(bb)) do path
        endswith(path, ".jls") || return false
        return true
    end

    nothing

end