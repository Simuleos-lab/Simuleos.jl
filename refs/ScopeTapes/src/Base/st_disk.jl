# root
#   |
#   |- config.json
#   |
#   | - blobs
#   |   |- index.jld2
#   |   |- 0x3882a83e9a454f5baa33e3d836a6b504.blob.jld2
#   |   |- 0xf96c4ccf672a4effb5963c52a918e879.blob.jld2
#   |
#   |- sessions
#   |   |- session-20250511-195329569-0x27ae
#   |   |   |- session.meta.jld2
#   |   |   |- scope-batch-20250511-196010111-0x1a3e.jld2
#   |   |   |
#   |   |   | 
#   |   |   | 
#
#



function st_new_scopebatch_name()
    return string("scope-batch-", _timed_hash(now()), ".jld2")
end

function st_new_session_name()
    return string("session-", _timed_hash(now()))
end

function st_blobfile(ST::ScopeTape, st_hash::String)
    return joinpath(ST.root, "blobs", string(st_hash, ".jld2"))
end

function st_manifestfile(ST::ScopeTape, manid)
    return joinpath(ST.root, "manifests", string(manid, ".jld2"))
end

NEW_BATCHFILE_COUNTER = 0
function st_new_scope_batchfile(ST::ScopeTape)
    ttag = Dates.format(now(), "yyyymmdd-HHMMSSS")
    rtag = repr(rand(UInt32))
    global NEW_BATCHFILE_COUNTER
    ctag = NEW_BATCHFILE_COUNTER
    NEW_BATCHFILE_COUNTER += 1;
    return joinpath(ST.root, "scopes", string(
        ttag, "-", ctag, "-", rtag, ".jld2"
    ))
end

function st_serialize(file::String, blob::Any)
    mkpath(dirname(file))
    # jldopen(file, "w") do io
    #     write(io, "obj", blob)
    # end
    serialize(file, blob)
    return nothing
end

function st_deserialize(file::String, dflt)
    !isfile(file) && return dflt
    # return jldopen(file, "r") do io
    #     read(io, "obj")
    # end
    deserialize(file)
end
