import Base.getindex
function getindex(scv::ScopeVariable)
    if scv.st_class === :primitive
        return scv.val
    end
    if scv.st_class === :nullblob
        error("nullblob: key `$(scv.key)`")
    end

    if scv.st_class === :blob
        blob = _st_get_blob(__ST, scv.st_hash)
        scv.val = blob
        return scv.val
    end
end