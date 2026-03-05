@testset "Settings Access Tracking" begin
    Kernel = Simuleos.Kernel
    WS = Simuleos.WorkSession

    with_test_context() do ctx
        sim = Kernel._get_simos()
        proj = Kernel.sim_project(sim)

        # Set some settings values
        Kernel.settings_layer_set!(sim, :script, "run.alpha", 0.5)
        Kernel.settings_layer_set!(sim, :script, "run.beta", 1.0)
        Kernel.settings_layer_set!(sim, :script, "run.gamma", "test")

        # Init session — should set up access log
        ws = WS.session_init!(sim, proj; labels=["tracking-test"])

        @testset "log is initialized on session_init!" begin
            @test ws.settings_access_log isa Dict{String, Any}
            @test isempty(ws.settings_access_log)
            @test ws.settings_access_tracking == true
        end

        @testset "settings populates access log" begin
            val = Kernel.settings(sim, "run.alpha")
            @test val == 0.5
            @test haskey(ws.settings_access_log, "run.alpha")
            @test ws.settings_access_log["run.alpha"] == 0.5

            Kernel.settings(sim, "run.beta")
            @test haskey(ws.settings_access_log, "run.beta")

            # Missing key also logged (with nothing value)
            Kernel.settings(sim, "nonexistent.key", nothing)
            @test haskey(ws.settings_access_log, "nonexistent.key")
            @test ws.settings_access_log["nonexistent.key"] === nothing
        end

        @testset "flush returns log and resets" begin
            flushed = WS._flush_settings_access_log!(ws)
            @test flushed isa Dict{String, Any}
            @test haskey(flushed, "run.alpha")
            @test haskey(flushed, "run.beta")
            @test isempty(ws.settings_access_log)

            # Second flush returns empty
            flushed2 = WS._flush_settings_access_log!(ws)
            @test isempty(flushed2)
        end

        @testset "tracking toggle" begin
            # Turn off tracking
            ws.settings_access_tracking = false
            Kernel.settings(sim, "run.gamma")
            @test !haskey(ws.settings_access_log, "run.gamma")

            # Turn back on
            ws.settings_access_tracking = true
            Kernel.settings(sim, "run.gamma")
            @test haskey(ws.settings_access_log, "run.gamma")
        end

        @testset "flush with nil log returns empty" begin
            ws.settings_access_log = nothing
            result = WS._flush_settings_access_log!(ws)
            @test isempty(result)
        end
    end
end
