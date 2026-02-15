ENV["SIMULEOS_TEST_MODE"] = "true"

using Simuleos
using Test

include("test-init.jl")

try
    test_init!()

    @testset "Simuleos.jl" begin
        @test 1 == 1
    end

    include("git_tests.jl")
    include("simignore_tests.jl")
    include("scoperias_tests.jl")
    include("query_tests.jl")
finally
    test_cleanup!()
end
