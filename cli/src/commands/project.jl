function print_project_current_help(io::IO = stdout)
    println(io, "Usage:")
    println(io, "  simules project.current [path]")
    println(io, "")
    println(io, "Options:")
    println(io, "  -h, --help  Show this help.")
end

function _project_current_parse_args(args::Vector{String})
    path = pwd()
    got_positional = false
    for arg in args
        if arg == "-h" || arg == "--help"
            return nothing
        elseif startswith(arg, "-")
            error("Unknown option: $(arg)")
        else
            got_positional && error("Only one positional path is supported.")
            got_positional = true
            path = arg
        end
    end
    return (path = path,)
end

function project_current_command(args::Vector{String}; io::IO = stdout, err_io::IO = stderr)::Int
    parsed = nothing
    try
        parsed = _project_current_parse_args(args)
    catch err
        println(err_io, "Error: $(sprint(showerror, err))")
        println(err_io, "")
        print_project_current_help(err_io)
        return 2
    end

    isnothing(parsed) && (print_project_current_help(io); return 0)

    project = nothing
    try
        project = Simuleos.Kernel.proj_find_and_init(parsed.path)
    catch err
        println(err_io, "Error: $(sprint(showerror, err))")
        return 1
    end

    if isnothing(project)
        println(err_io, "Error: No .simuleos project found at or above: $(parsed.path)")
        return 1
    end

    id_str = isnothing(project.id) ? "(missing)" : string(project.id)
    println(io, "Project")
    println(io, "  root:         $(project.root_path)")
    println(io, "  simuleos_dir: $(project.simuleos_dir)")
    println(io, "  id:           $(id_str)")
    return 0
end
