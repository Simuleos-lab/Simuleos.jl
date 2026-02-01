function st_write!(
    ST::ScopeTape
)
    isempty(ST.recording_scope_cache) && return
    
    global __ST_LK_FILE
    lock(__ST_LK_FILE) do

        # validate blobs
        # - only write blobs present in the scopes
        valid_blobs = Dict{String, Any}()
        for (sc_hash, sc) in ST.recording_scope_cache
            for (key, scv) in sc
                # @show scv
                scv.st_class === :blob || continue
                haskey(ST.recording_blob_cache, scv.st_hash) || continue
                valid_blobs[scv.st_hash] = ST.recording_blob_cache[scv.st_hash]
            end
        end
        
        # write blobs
        for (hash, blob) in valid_blobs
            blobfile = st_blobfile(ST, hash)
            isfile(blobfile) && continue
            st_serialize(blobfile, blob)
        end
        
        # write scope batch
        batchfile = st_new_scope_batchfile(ST)
        st_serialize(batchfile, ST.recording_scope_cache)

        # manifest
        _st_mod_manifest!(ST, "registered.batches"; lk = nothing) do rb_man
            batches = get!(rb_man, "registry", String[])
            push!(batches, basename(batchfile))
        end

        empty!(ST.recording_scope_cache)
        empty!(ST.recording_blob_cache)

        return
    end
end

macro st_write!()
    quote
        ScopeTapes.st_write!(ScopeTapes.__ST)
    end
end

function st_flush!(ST::ScopeTape)
    empty!(ST.recording_scope_cache)
    empty!(ST.recording_blob_cache)
end


macro st_flush!(lb="")
    quote
        # create label
        if (!isempty($(lb)))
            ScopeTapes.@st_label $(lb)
        end
        ScopeTapes.st_flush!(ScopeTapes.__ST)
    end |> esc
end