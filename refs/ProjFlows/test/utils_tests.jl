let
    # parseARGS
    ARGSbk = deepcopy(ARGS)
    try
        empty!(ARGS)
        push!(ARGS, "SIMVER:ECOLI-CORE-BEG2007-PHASE_I-0.1.0")
        push!(ARGS, "NTHREADS:18")
        push!(ARGS, "FLAG:")
        @test parseARGS("SIMVER:") == "ECOLI-CORE-BEG2007-PHASE_I-0.1.0"
        @test parseARGS(Int, "NTHREADS:") isa Int
        @test parseARGS(Int, "NTHREADS:") == 18
        @test_throws "ARG not found" parseARGS("NOTFOUND:")
        @test !parseARGS(isnothing, "FLAG:")
        @test parseARGS(isempty, "FLAG:")
        @test parseARGS(isnothing, "NOFLAG:")
    finally
        empty!(ARGS)
        push!(ARGS, ARGSbk...)
    end
end