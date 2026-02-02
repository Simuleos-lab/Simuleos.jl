using Simuleos
using Test

@testset "Simuleos.jl" begin
    @test 1 == 1
    
    # Include metadata tests
    include("test_metadata.jl")
end
