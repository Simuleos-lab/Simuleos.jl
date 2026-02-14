# Project driver methods (all I1x - explicit subsystem objects)

proj_path(project::Project)::String = project.root_path
simuleos_dir(project::Project)::String = project.simuleos_dir
proj_json_path(project::Project)::String = _proj_json_path(project.root_path)
settings_path(project::Project)::String = _proj_settings_path(project.root_path)
tape_path(project::Project)::String = tape_path(project.simuleos_dir)

blob_path(project::Project, sha1::String)::String = blob_path(project.blobstorage, sha1)

function proj_is_init(proj::Project)::Bool
    proj_json = proj_json_path(proj)
    return isfile(proj_json)
end

function proj_init!(proj::Project)::Project
    proj_sim = simuleos_dir(proj)
    proj_json = proj_json_path(proj)
    mkpath(proj_sim)

    if !isfile(proj_json)
        proj.id = string(UUIDs.uuid4())
        open(proj_json, "w") do io
            JSON3.pretty(io, Dict("id" => proj.id))
        end
        return proj
    end

    pjdata = open(proj_json, "r") do io
        JSON3.read(io, Dict{String, Any})
    end
    id = get(pjdata, "id", nothing)
    isnothing(id) && error("project.json is missing 'id' field: $proj_json")
    proj.id = string(id)

    return proj
end
