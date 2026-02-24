function print_system_init_help(io::IO = stdout)
    println(io, "Usage:")
    println(io, "  simules system.init [path]")
    println(io, "")
    println(io, "Options:")
    println(io, "  -h, --help  Show this help.")
end

function _system_init_parse_args(args::Vector{String})
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

function system_init_command(args::Vector{String}; io::IO = stdout, err_io::IO = stderr)::Int
    parsed = nothing
    try
        parsed = _system_init_parse_args(args)
    catch err
        println(err_io, "Error: $(sprint(showerror, err))")
        println(err_io, "")
        print_system_init_help(err_io)
        return 2
    end

    isnothing(parsed) && (print_system_init_help(io); return 0)

    root = abspath(parsed.path)
    sim_dir = Simuleos.Kernel._simuleos_dir(root)
    pj_path = Simuleos.Kernel.project_json_path(sim_dir)
    was_existing = isfile(pj_path)

    project = nothing
    try
        project = Simuleos.Kernel.proj_init_at(parsed.path)
    catch err
        println(err_io, "Error: $(sprint(showerror, err))")
        return 1
    end

    status = was_existing ? "loaded" : "created"
    println(io, "System initialized.")
    println(io, "  root:         $(project.root_path)")
    println(io, "  simuleos_dir: $(project.simuleos_dir)")
    println(io, "  id:           $(project.id)")
    println(io, "  status:       $(status)")
    return 0
end
