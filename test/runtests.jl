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
    include("worksession_tests.jl")
    include("settings_tests.jl")
    include("scoperias_tests.jl")
    include("dataclass_types_tests.jl")
    include("class_registry_tests.jl")
    include("settings_tracking_tests.jl")
    include("recording_tests.jl")
    include("context_capture_tests.jl")
    include("cli_args_tests.jl")
    include("query_tests.jl")
    include("scope_reader_tests.jl")
    include("sqlite_index_tests.jl")
    include("simos_macro_tests.jl")
    include("jmespath_tests.jl")
    include("query_command_tests.jl")
finally
    test_cleanup!()
end
