## --.--. - .-. .- .--.-.- .- .---- ... . .-.-.-.- 

import Base.show
function Base.show(io::IO, b::bBlob)
    print(io, "Blob(")
    printstyled(io, repr(b.uuid); color = :blue)
    print(io, ")")

    # depot frames
    frames_kTv = Dict()
    _push_frames_kTv!(frames_kTv, b) do k
        k isa String && return true
        return false
    end
    if !isempty(frames_kTv)
        print(io, "\n\nDepot blobs: \n")
        _print_frames_kTv(io, frames_kTv)
    end
end