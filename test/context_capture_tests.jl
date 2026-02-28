@testset "Context Capture & Resolve" begin
    Kernel = Simuleos.Kernel
    WS = Simuleos.WorkSession

    with_test_context() do ctx
        sim = Kernel._get_sim()
        proj = Kernel.sim_project(sim)

        # Set some settings
        Kernel.settings_layer_set!(sim, :script, "run.alpha", 0.5)
        Kernel.settings_layer_set!(sim, :script, "run.beta", 1.0)

        # Init session
        ws = WS.session_init!(sim, proj; labels=["context-test"])

        @testset "context_capture! returns RecordRef" begin
            # Access some settings to populate the log
            Kernel.get_setting(sim, "run.alpha")
            Kernel.get_setting(sim, "run.beta")

            ref = WS.context_capture!(ws, proj)
            @test ref isa Kernel.RecordRef
            @test length(ref.hash) == 40
            @test length(ref.short) == Kernel.RECORD_REF_SHORT_LEN
        end

        @testset "context_resolve retrieves full tree" begin
            # Access a setting and capture
            Kernel.get_setting(sim, "run.alpha")
            ref = WS.context_capture!(ws, proj)

            # Resolve
            data = WS.context_resolve(proj, ws, ref.hash)
            @test data isa Dict{String, Any}
            @test data["class_id"] == "snap.context"
            @test data["class_version"] == 1
            @test haskey(data, "session_id")
            @test data["session_id"] == string(ws.session_id)
            @test haskey(data, "labels")
            @test haskey(data, "execution")
            @test data["execution"]["type"] == "execution_capture"
        end

        @testset "context tree includes source and environment" begin
            ref = WS.context_capture!(ws, proj)
            data = WS.context_resolve(proj, ws, ref.hash)

            @test haskey(data, "source")
            @test data["source"]["type"] == "source_capture"

            @test haskey(data, "environment")
            @test data["environment"]["type"] == "environment_capture"
            @test data["environment"]["julia_version"] == string(VERSION)
        end

        @testset "context tree includes settings when accessed" begin
            Kernel.get_setting(sim, "run.alpha")
            ref = WS.context_capture!(ws, proj)
            data = WS.context_resolve(proj, ws, ref.hash)

            @test haskey(data, "settings")
            @test data["settings"]["type"] == "settings_capture"
            @test data["settings"]["accessed"]["run.alpha"] == 0.5
        end

        @testset "settings log flushed after capture" begin
            Kernel.get_setting(sim, "run.beta")
            WS.context_capture!(ws, proj)

            # Log should be flushed
            @test isempty(ws.settings_access_log)
        end

        @testset "resolve by short prefix" begin
            ref = WS.context_capture!(ws, proj)
            data = WS.context_resolve(proj, ws, ref.short)
            @test data isa Dict{String, Any}
            @test data["session_id"] == string(ws.session_id)
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
