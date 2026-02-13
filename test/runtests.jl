using Simuleos
using Test

@testset "Simuleos.jl" begin
    @test 1 == 1
    
    # Include metadata tests
    include("test_metadata.jl")
end

include("git_tests.jl")
include("simignore_tests.jl")
include("query_tests.jl")
