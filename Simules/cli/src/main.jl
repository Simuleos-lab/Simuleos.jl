include("SimulesCLI.jl")

exit_code = SimulesCLI.main(copy(ARGS))
exit(exit_code)
