function print_blob_meta_help(io::IO = stdout)
    println(io, "Usage:")
    println(io, "  simules blob.meta <hash_or_ref> [--project=path]")
    println(io, "")
    println(io, "Options:")
    println(io, "  -h, --help        Show this help.")
    println(io, "  --project <path>  Project root or nested path (default: current directory).")
end

function _blob_meta_parse_args(args::Vector{String})
    project_path = pwd()
    hash_or_ref = nothing
    i = 1
    while i <= length(args)
        arg = args[i]
        if arg == "-h" || arg == "--help"
            return nothing
        elseif arg == "--project"
            i += 1
            i > length(args) && error("Missing value for --project.")
            project_path = args[i]
        elseif startswith(arg, "--project=")
            project_path = String(split(arg, "="; limit=2)[2])
        elseif startswith(arg, "-")
            error("Unknown option: $(arg)")
        else
            !isnothing(hash_or_ref) && error("Only one positional hash/ref is supported.")
            hash_or_ref = arg
        end
        i += 1
    end
    isnothing(hash_or_ref) && error("Missing required argument: hash_or_ref.")
    return (hash_or_ref = hash_or_ref, project_path = project_path)
end

function blob_meta_command(args::Vector{String}; io::IO = stdout, err_io::IO = stderr)::Int
    parsed = nothing
    try
        parsed = _blob_meta_parse_args(args)
    catch err
        println(err_io, "Error: $(sprint(showerror, err))")
        println(err_io, "")
        print_blob_meta_help(err_io)
        return 2
    end

    isnothing(parsed) && (print_blob_meta_help(io); return 0)

    project = nothing
    try
        project = Simuleos.Kernel.proj_find_and_init(parsed.project_path)
    catch err
        println(err_io, "Error: $(sprint(showerror, err))")
        return 1
    end

    if isnothing(project)
        println(err_io, "Error: No .simuleos project found at or above: $(parsed.project_path)")
        return 1
    end

    metadata = Simuleos.Kernel.blob_metadata(project, parsed.hash_or_ref)
    if isnothing(metadata)
        println(io, "(not found)")
        return 1
    end

    for (k, v) in sort(collect(metadata); by = x -> x[1])
        println(io, "$(k): $(v)")
    end
    return 0
end
