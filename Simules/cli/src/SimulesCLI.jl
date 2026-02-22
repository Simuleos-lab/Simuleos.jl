module SimulesCLI

import Simuleos

include("commands/stats.jl")

function print_help(io::IO = stdout)
    println(io, "Simules CLI")
    println(io, "")
    println(io, "Usage:")
    println(io, "  simules <command> [options]")
    println(io, "")
    println(io, "Commands:")
    println(io, "  stats [path]     Print a project-state report.")
    println(io, "  help             Show this help.")
end

function _dispatch(command::String, args::Vector{String}; io::IO = stdout, err_io::IO = stderr)::Int
    if command == "stats"
        return stats_command(args; io=io, err_io=err_io)
    end
    if command == "help" || command == "-h" || command == "--help"
        print_help(io)
        return 0
    end
    println(err_io, "Unknown command: $(command)")
    println(err_io, "")
    print_help(err_io)
    return 2
end

function main(args::Vector{String} = copy(ARGS); io::IO = stdout, err_io::IO = stderr)::Int
    if isempty(args)
        print_help(io)
        return 0
    end
    return _dispatch(args[1], args[2:end]; io=io, err_io=err_io)
end

end # module SimulesCLI
