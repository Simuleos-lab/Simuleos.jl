## --.--. - .-. .- .--.-.- .- .---- ... . .-.-.-.- 
# Base

import Base.getindex
Base.getindex(rc::RefCacher, ref::BlobyRef) = deref(rc, ref)

## --.--. - .-. .- .--.-.- .- .---- ... . .-.-.-.- 
# This one returns the blob
# - the ref is an input
function blobio!(f::Function, 
        ref::BlobyRef, 
        mode::Symbol = :get!;
        ab = deref_srcblob(ref)
    )
    frame = ref.link["val.frame"]::String
    key = ref.link["val.key"]::String
    blobio!(f, ab, frame, key, mode)
    return ab
end