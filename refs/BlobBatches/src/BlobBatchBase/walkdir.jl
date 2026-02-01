import Base.walkdir
# 'walkdir' all directories and parse them as BlobBatch
function Base.walkdir(::Type{BlobBatch}, root::AbstractString; 
        topdown=true, follow_symlinks=false, onerror=throw, 
        skipempty = true, 
        chsize = 2
    )
    return Channel{BlobBatch}(chsize) do _ch
        for (currdir, dirs, _) in walkdir(root; topdown, follow_symlinks, onerror)
            for dir in dirs
                # path to directories
                dir = joinpath(currdir, dir)
                isfile(dir) && continue
                bb = BlobBatch(dir)
                skipempty && isempty(bb) && continue
                put!(_ch, bb)
            end
        end
    end
end

import Base.readdir
function Base.readdir(::Type{BlobBatch}, root::AbstractString;
        perm::Function = sort!,
        skipempty = true, 
        chsize = 2
    )
    files = perm(readdir(root; join = false, sort = false))
    return Channel{BlobBatch}(chsize) do _ch
        for dir in files
            dir = joinpath(root, dir)
            isfile(dir) && continue
            bb = BlobBatch(dir)
            skipempty && isempty(bb) && continue
            put!(_ch, bb)
        end
    end
end

