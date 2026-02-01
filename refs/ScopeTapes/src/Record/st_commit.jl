# - push scope into batch
# - check that no previous commit was done for cuttent scope

# DOING
# - avoid injecting unessesary variables

macro st_commit(lb = "")
    quote
        ScopeTapes.@_post_init_check()

        # handle commit done
        # @show ScopeTapes.@_tryvalue(ST_COMMIT_WH)
        ScopeTapes.@_tryvalue(ST_COMMIT_WH) == true &&
            error("A previous commit call detected in current scope!. Avoid committing in global scope.")
        ST_COMMIT_WH = true

        # create label
        isempty($(lb)) || ScopeTapes.@st_label $(lb)

        # SC
        let
            # process scope
            local rawscope = ScopeTapes.@st_rawscope()
            local ST = ScopeTapes.__ST
            local rec_sc_cache = ST.recording_scope_cache
            local scope = ScopeTapes.st_run_hooks!(ST, rawscope; docache = true)
            local scope_hash = st_blob_hash(scope)
            local rec_head_hash, rec_head_sc = ScopeTapes.st_rec_head(ST, (nothing, nothing))
            if isnothing(rec_head_sc)
                # new scope
                rec_sc_cache[scope_hash] = scope
            elseif (ScopeTapes._st_already_in_batch(ST, scope_hash))
                @info "Already in batch: Nothing to commit"
            elseif ScopeTapes._st_is_subset(scope.sc, rec_head_sc.sc)
                @info "Subset: Nothing to commit"
            elseif ScopeTapes._st_is_subset(rec_head_sc.sc, scope.sc)
                @info "Superset: rebasing"
                rec_sc_cache[scope_hash] = scope
            else
                # new scope
                rec_sc_cache[scope_hash] = scope
            end

            # check write
            local config = ScopeTapes.@st_config()
            local write_len = get(config, "do.write.batch.at.len", typemax(Int))
            local staged_len = length(rec_sc_cache)
            if (staged_len >= write_len)
                @info "TAPE: writing"
                ScopeTapes.st_write!(ScopeTapes.__ST)
            end
        end
        
        nothing
    end |> esc
end

function st_rec_head(ST::ScopeTape, dflt)
    length(ST.recording_scope_cache) == 0 && return dflt
    return last(ST.recording_scope_cache)
end

function _st_already_in_batch(ST::ScopeTape, sch::String)
    return haskey(ST.recording_scope_cache, sch)
end