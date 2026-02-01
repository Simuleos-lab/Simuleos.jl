## ------------------------------------------------------------
# Inspired in DrWatson: quickactivate but reduce LOAD_PATH
function quickactivate(path = pwd(), name = "")

    # setup
    path = string(path)
    name = string(name)

    # find project
    path = abspath(path)
    currproj = Base.current_project(path)
    (isnothing(currproj) || !isfile(currproj)) && error("No project found from '$(path)'")

    # check name
    projname = basename(dirname(currproj))
    !isempty(name) && (projname != name) && error("Unexpected project name, expected '$(name)' got '$(projname)'")

    # activate
    actproj = Base.active_project()   
    (currproj != actproj) && Pkg.activate(currproj)

    # restrict LOAD_PATH
    empty!(LOAD_PATH)
    push!(LOAD_PATH, "@", "@stdlib")

    return nothing
end

# ------------------------------------------------------------
macro quickactivate(name = nothing)
    path = String(__source__.file)
    !ispath(path) && (path = pwd())
    name = isnothing(name) ? "" : string(name)
    quickactivate(path, name)
    return :(nothing)
end