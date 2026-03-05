@testset "Context Capture & Resolve" begin
    Kernel = Simuleos.Kernel
    WS = Simuleos.WorkSession

    with_test_context() do ctx
        sim = Kernel._get_simos()
        proj = Kernel.sim_project(sim)

        Kernel.settings_layer_set!(sim, :script, "run.alpha", 0.5)
        Kernel.settings_layer_set!(sim, :script, "run.beta", 1.0)

        ws = WS.session_init!(sim, proj; labels=["context-test"])

        @testset "context_capture! returns RecordRef" begin
            Kernel.settings(sim, "run.alpha")
            Kernel.settings(sim, "run.beta")

            ref = WS.context_capture!(ws, proj)
            @test ref isa Kernel.RecordRef
            @test length(ref.hash) == 40
            @test length(ref.short) == Kernel.RECORD_REF_SHORT_LEN
        end

        @testset "context_resolve returns typed context" begin
            Kernel.settings(sim, "run.alpha")
            ref = WS.context_capture!(ws, proj)

            data = WS.context_resolve(proj, ws, ref.hash)
            @test data isa Kernel.SnapContextV1
            @test data.session_id == string(ws.session_id)
            @test data.labels == ws.labels
            @test data.execution isa Kernel.SrcExecutionSiteV1
            @test !isempty(data.execution.timestamp)
        end

        @testset "context includes source and environment" begin
            ref = WS.context_capture!(ws, proj)
            data = WS.context_resolve(proj, ws, ref.hash)

            @test data isa Kernel.SnapContextV1
            @test data.source isa Kernel.SrcCodebaseV1
            @test data.environment isa Kernel.SrcRuntimeHostV1
            @test data.environment.julia_version == string(VERSION)
        end

        @testset "context includes settings when accessed" begin
            Kernel.settings(sim, "run.alpha")
            ref = WS.context_capture!(ws, proj)
            data = WS.context_resolve(proj, ws, ref.hash)

            @test data isa Kernel.SnapContextV1
            @test data.settings isa Kernel.SrcSettingsAccessV1
            @test data.settings.accessed["run.alpha"] == 0.5
        end

        @testset "settings log flushed after capture" begin
            Kernel.settings(sim, "run.beta")
            WS.context_capture!(ws, proj)
            @test isempty(ws.settings_access_log)
        end

        @testset "resolve by short prefix" begin
            ref = WS.context_capture!(ws, proj)
            data = WS.context_resolve(proj, ws, ref.short)
            @test data isa Kernel.SnapContextV1
            @test data.session_id == string(ws.session_id)
        end

        @testset "resolve nonexistent returns nothing" begin
            result = WS.context_resolve(proj, ws, "0000000000000000000000000000000000000000")
            @test isnothing(result)
        end

        @testset "string interpolation with RecordRef" begin
            ref = WS.context_capture!(ws, proj)
            filename = "plot_$(ref).png"
            @test endswith(filename, ".png")
            @test startswith(filename, "plot_")
            @test length(filename) > length("plot_.png")
        end
    end
end
