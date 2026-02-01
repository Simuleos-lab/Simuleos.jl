function _hex_escape(s::String) 
    tcstr = transcode(UInt8, s)
    strs = String[]
    for tcchar in tcstr
        s = string("\\x", string(tcchar; pad = sizeof(tcchar)<<1, base = 16))
        push!(strs, s)
    end
    strs
end
_hex_escape(s) = _hex_escape(string(s))

