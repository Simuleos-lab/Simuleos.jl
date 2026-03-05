@testset "DataClass Types" begin
    Kernel = Simuleos.Kernel

    @testset "SimuleosDataClass constructors" begin
        sc = Kernel.SrcSettingsAccessV1(
            Dict{String, Any}("key1" => 1, "key2" => "val"),
            "2026-01-01T00:00:00",
        )
        @test sc isa Kernel.SimuleosDataClass
        @test sc.accessed["key1"] == 1

        src = Kernel.SrcCodebaseV1("abc123", "main", false, "v1.0")
        @test src isa Kernel.SimuleosDataClass
        @test src.git_commit == "abc123"
        @test src.git_branch == "main"
        @test src.git_dirty == false

        env = Kernel.SrcRuntimeHostV1("1.10.0", "host", "Linux", 64, 4, "2026-01-01T00:00:00")
        @test env isa Kernel.SimuleosDataClass
        @test env.julia_version == "1.10.0"
        @test env.threads == 4

        exec = Kernel.SrcExecutionSiteV1("test.jl", 42, 1, "2026-01-01T00:00:00")
        @test exec isa Kernel.SimuleosDataClass
        @test exec.src_file == "test.jl"
        @test exec.src_line == 42

        scope = Kernel.SnapScopeV1()
        @test scope isa Kernel.SimuleosDataClass
        @test scope isa Kernel.SnapScopeV1
        @test isempty(scope.labels)
        @test isempty(scope.variables)
        @test isempty(scope.metadata)

        shared = Kernel.SnapSharedV1()
        @test shared isa Kernel.SimuleosDataClass
        @test shared isa Kernel.SnapSharedV1
        @test isempty(shared.labels)
        @test isempty(shared.variables)
        @test isempty(shared.metadata)
        @test shared.shared_key == ""

    end

    @testset "Pure collectors" begin
        # capture_source(nothing) returns zeroed capture
        src_nil = Kernel.capture_source(nothing)
        @test src_nil isa Kernel.SrcCodebaseV1
        @test src_nil.git_commit == ""
        @test src_nil.git_branch == ""
        @test src_nil.git_dirty == false

        # capture_environment returns real runtime data
        env = Kernel.capture_environment()
        @test env isa Kernel.SrcRuntimeHostV1
        @test env.julia_version == string(VERSION)
        @test !isempty(env.hostname)
        @test env.word_size > 0
        @test env.threads >= 1

        # capture_execution with and without args
        exec = Kernel.capture_execution("foo.jl", 10)
        @test exec isa Kernel.SrcExecutionSiteV1
        @test exec.src_file == "foo.jl"
        @test exec.src_line == 10
        @test exec.threadid >= 1

        exec0 = Kernel.capture_execution()
        @test exec0.src_file == ""
        @test exec0.src_line == 0

    end

    @testset "serialize_capture" begin
        captures = Kernel.SimuleosDataClass[
            Kernel.SrcSettingsAccessV1(Dict{String, Any}("k" => 1.5), "2026-01-01T00:00:00"),
            Kernel.SrcCodebaseV1("deadbeef", "feature", true, "v2.0-3-gabc"),
            Kernel.SrcRuntimeHostV1("1.11.0", "node1", "Darwin", 64, 8, "2026-02-25T12:00:00"),
            Kernel.SrcExecutionSiteV1("script.jl", 100, 2, "2026-02-25T12:00:01"),
        ]

        for original in captures
            serialized = Kernel.serialize_capture(original)
            @test serialized isa Dict{String, Any}
            @test haskey(serialized, "class_id")
            @test haskey(serialized, "class_version")
        end
    end

    @testset "Phase 3: captures in session lifecycle" begin
        WS = Simuleos.WorkSession

        with_test_context() do ctx
            sim = Kernel._get_simos()
            proj = Kernel.sim_project(sim)

            ws = WS.session_init!(sim, proj; labels=["lifecycle-test"])

            # Source capture should be populated (may be zeroed if no git)
            @test ws.source_capture isa Kernel.SrcCodebaseV1

            # Environment capture should have real runtime data
            @test ws.environment_capture isa Kernel.SrcRuntimeHostV1
            env = ws.environment_capture
            @test env.julia_version == string(VERSION)
            @test !isempty(env.hostname)
            @test env.threads >= 1
        end
    end
end
