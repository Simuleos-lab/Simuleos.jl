## --------------------------------------------------------
struct BlobBatch
    frames::OrderedDict{String, Any}
    function BlobBatch() 
        bb = new(OrderedDict{String, Any}())
        return bb
    end
end

function BlobBatch(root::AbstractString)
    bb = BlobBatch()
    rootdir!(bb, root)
    return bb
end