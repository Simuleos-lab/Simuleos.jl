## --.--. -. -. .. . .- -- .-. -- .- -. -- .- .- .- -.- .- .. -.
import Base.getindex
Base.getindex(ab::AbstractBlob, ref::BlobyRef) = deref(ab, ref)

import Base.setindex!
Base.setindex!(ab::AbstractBlob, val, ref::BlobyRef) =
    setindex!(ab, val,
        ref.link["val.frame"]::String, 
        ref.link["val.key"]::String
    )