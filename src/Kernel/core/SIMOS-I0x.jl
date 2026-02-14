# SIMOS helpers (all I0x - explicit path loading)

function _load_project(proj_path::String)::Project
    pjpath = _proj_json_path(proj_path)
    pjdata = open(pjpath, "r") do io
        JSON3.read(io, Dict{String, Any})
    end

    id = get(pjdata, "id", nothing)
    isnothing(id) && error("project.json is missing 'id' field: $pjpath")

    sd = _simuleos_dir(proj_path)
    return Project(
        id = string(id),
        root_path = proj_path,
        simuleos_dir = sd,
        blobstorage = BlobStorage(sd)
    )
end
