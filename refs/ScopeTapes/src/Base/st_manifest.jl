#=
    The manifest contain state data of the tape. 
    This data can be synced between threads/proccesses
=#

function _st_manifest(ST::ScopeTape, manid::String; lk)
    
    # cache
    man_cache = get!(ST.extras, "manifest.cache", Dict{String, Any}())
    mtime_reg = get!(ST.extras, "manifest.last.mtimes", Dict{String, Any}())
    
    # check validity
    manfile = st_manifestfile(ST, manid)
    curr_mtime = mtime(manfile)
    last_mtime = get!(mtime_reg, manid, nothing)
    
    # return if valid
    if last_mtime == curr_mtime 
        ram_man = get(man_cache, manid, Dict{String, Any}())
        return ram_man
    end
    
    return _lock(lk) do
        # load manifest
        disk_man = st_deserialize(manfile, Dict{String, Any}())

        # merge with ram
        ram_man =  get!(man_cache, manid, Dict{String, Any}())
        empty!(ram_man)
        merge!(ram_man, disk_man)

        # Up mtime registry
        mtime_reg[manid] = curr_mtime

        return disk_man
    end
end
st_manifest(manid::String) = _st_manifest(__ST, manid; lk = __ST_LK_FILE)


function _st_mod_manifest!(f::Function, ST::ScopeTape, manid::String; lk)
    _lock(lk) do
        tape_man = _st_manifest(ST, manid; lk = nothing)
        ret = f(tape_man)
        ret == :abort && return
        # write
        manfile = st_manifestfile(ST, manid)
        st_serialize(manfile, tape_man)
    end
    nothing
end
st_mod_manifest!(f::Function, manid::String) = 
    _st_mod_manifest!(f, __ST, manid; lk = __ST_LK_FILE)
