## --.--. - .-. .- .--.-.- .- .---- ... . .-.-.-.- 
# Bloberia interface

bloberia(b::bBlob) = bloberia(b.bb)
blobbatch(b::bBlob) = b.bb

## --.--. - .-. .- .--.-.- .- .---- ... . .-.-.-.- 
# lock interface
function _lock_obj_identity_hash(b::bBlob, h0 = UInt64(0))::UInt64
    h = _lock_obj_identity_hash(b.bb, h0)
    h = hash(:bBlob, h)
    h = hash(b.uuid, h)
    return h
end

## --.--. - .-. .- .--.-.- .- .---- ... . .-.-.-.- 

_gettemp_I!(b::bBlob) = _gettemp_I!(b.bb)