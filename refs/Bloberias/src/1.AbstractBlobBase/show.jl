function _push_frames_kTv!(kfil::Function, frames_kTv, ab)
    for frameid in _depotframes(ab)
        _blob = _depot_blob(ab, frameid)
        isnothing(_blob) && continue
        get!(frames_kTv, frameid) do
            Set()
        end
        for (_k, _dat) in _blob
            kfil(_k) === true || continue
            push!(frames_kTv[frameid], _k => typeof(_dat))
        end
    end
end

function _print_frames_kTv(io, frames_kTv)
    for (frameid, _kvT) in frames_kTv
        isempty(_kvT) && continue
        print(io, "  ",  repr(frameid))
        println(io)
        print(io, "    ")
        _kv_print_type(io, _kvT; _typeof = identity)
        println(io)
    end
end