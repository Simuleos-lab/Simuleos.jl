# SIMOS helpers (all I0x - explicit path loading)

function _load_project(path::String)::Project
    pjpath = project_json_path(path)
    pjdata = open(pjpath, "r") do io
        JSON3.read(io, Dict{String, Any})
    end

    id = get(pjdata, "id", nothing)
    isnothing(id) && error("project.json is missing 'id' field: $pjpath")

    sd = simuleos_dir(path)
    return Project(
        id = id,
        root_path = path,
        simuleos_dir = sd,
        blobstorage = BlobStorage(sd)
    )
end
