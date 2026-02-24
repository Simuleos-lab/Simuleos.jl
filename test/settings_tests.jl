let
    kernel = Simuleos.Kernel

    @testset "settings stack (phase1) attaches to SimOs and preserves precedence" begin
        with_test_context() do ctx
            home_settings_path = joinpath(ctx[:home_path], kernel.SETTINGS_JSON)
            project_settings_path = kernel.settings_json_path(kernel._simuleos_dir(ctx[:project_path]))

            kernel._write_json_file(home_settings_path, Dict(
                "demo.key" => "home",
                "home.only" => 1,
            ))
            kernel._write_json_file(project_settings_path, Dict(
                "demo.key" => "project",
                "project.only" => 2,
            ))

            withenv(
                    "SIMULEOS_DEMO_KEY" => "env",
                    "SIMULEOS_ENV_ONLY" => "envv",
                ) do
                kernel.sim_reset!()
                kernel.sim_init!(
                    bootstrap = Dict{String, Any}(
                        "project.root" => ctx[:project_path],
                        "home.path" => ctx[:home_path],
                        "demo.key" => "bootstrap",
                        "bootstrap.only" => 3,
                    ),
                )

                sim = kernel._get_sim()
                @test !isnothing(sim.settings_stack)
                @test sim.settings === sim.settings_stack.effective
                @test [layer.name for layer in sim.settings_stack.layers] == [:home, :project, :env, :bootstrap, :script, :session]

                @test kernel.settings(sim, "demo.key") == "bootstrap"
                @test kernel.settings(sim, "home.only") == 1
                @test kernel.settings(sim, "project.only") == 2
                @test kernel.settings(sim, "env.only") == "envv"
                @test kernel.settings(sim, "bootstrap.only") == 3
            end
        end
    end

    @testset "settings stack lookup wrapper prefers settings_stack over legacy cache" begin
        stack = kernel.SettingsStack(;
            effective = Dict{String, Any}("demo.key" => "stack"),
        )
        sim = kernel.SimOs(
            settings = Dict{String, Any}("demo.key" => "legacy"),
            settings_stack = stack,
        )
        @test kernel.get_setting(sim, "demo.key") == "stack"
    end

    @testset "settings normalize helpers flatten and unflatten dotted keys" begin
        nested = Dict{String, Any}(
            "solver" => Dict("tol" => 1e-6, "name" => "HiGHS"),
            "cache" => Dict("enabled" => true),
        )
        flat = kernel._settings_flatten_dict(nested)
        @test flat["solver.tol"] == 1e-6
        @test flat["solver.name"] == "HiGHS"
        @test flat["cache.enabled"] == true

        roundtrip = kernel._settings_unflatten_dict(flat)
        @test roundtrip["solver"]["tol"] == 1e-6
        @test roundtrip["solver"]["name"] == "HiGHS"
        @test roundtrip["cache"]["enabled"] == true

        @test_throws ErrorException kernel._settings_unflatten_dict(Dict(
            "solver" => "x",
            "solver.tol" => 1e-6,
        ))
        @test_throws ErrorException kernel._settings_flatten_dict(Dict(
            "solver" => Dict("tol" => 1e-6),
            "solver.tol" => 1e-4,
        ))
    end

    @testset "settings effective cache is lazy, versioned, and negatively caches misses" begin
        with_test_context() do ctx
            cfg = joinpath(ctx[:root_path], "lazy-cache.json")
            kernel._write_json_file(cfg, Dict("lazy" => Dict("value" => 10)))

            sim = kernel._get_sim()
            stack = sim.settings_stack
            @test !isnothing(stack)
            @test stack.effective_version == stack.version
            @test stack.effective_complete == false
            @test isempty(stack.effective)
            @test isempty(stack.effective_missing)

            @test kernel.get_setting(sim, "missing.key", :missing) == :missing
            @test "missing.key" in stack.effective_missing
            @test !haskey(stack.effective, "missing.key")
            @test stack.effective_complete == false

            @test kernel.get_setting(sim, "project.root") == ctx[:project_path]
            @test haskey(stack.effective, "project.root")
            @test stack.effective_complete == false

            snap = kernel._settings_stack_snapshot(stack)
            @test stack.effective_complete == true
            @test stack.effective_version == stack.version
            @test snap["project.root"] == ctx[:project_path]
            @test "project.root" in kernel._settings_stack_keys(stack)

            old_version = stack.version
            kernel.settings_source_add_json!(sim, cfg; name = :lazycfg)
            @test stack.version == old_version + 1
            @test stack.effective_version == stack.version
            @test stack.effective_complete == false
            @test isempty(stack.effective)
            @test isempty(stack.effective_missing)

            @test kernel.get_setting(sim, "lazy.value") == 10
            @test haskey(stack.effective, "lazy.value")
        end
    end

    @testset "settings sources add/remove/list/reload JSON layers" begin
        with_test_context() do ctx
            sim = kernel._get_sim()

            cfg1 = joinpath(ctx[:root_path], "cfg1.json")
            cfg2 = joinpath(ctx[:root_path], "cfg2.json")
            cfg_optional = joinpath(ctx[:root_path], "cfg-optional.json")

            kernel._write_json_file(cfg1, Dict(
                "run" => Dict("alpha" => 11),
                "demo.key" => "json1",
            ))
            kernel._write_json_file(cfg2, Dict(
                "run.beta" => 22,
                "demo.key" => "json2",
            ))

            layer1 = kernel.settings_source_add_json!(sim, cfg1; name = :run1)
            @test layer1.name == :run1
            @test kernel.get_setting(sim, "run.alpha") == 11
            @test kernel.get_setting(sim, "demo.key") == "json1"
            @test [layer.name for layer in sim.settings_stack.layers] == [:home, :project, :run1, :env, :bootstrap, :script, :session]

            layer2 = kernel.settings_source_add_json!(sim, cfg2; name = :run2, after = :run1)
            @test layer2.name == :run2
            @test kernel.get_setting(sim, "run.beta") == 22
            @test kernel.get_setting(sim, "demo.key") == "json2"
            @test [layer.name for layer in sim.settings_stack.layers] == [:home, :project, :run1, :run2, :env, :bootstrap, :script, :session]

            listed = kernel.settings_source_list(sim)
            @test [entry.name for entry in listed] == [:home, :project, :run1, :run2, :env, :bootstrap, :script, :session]
            @test listed[3].kind == :json_file
            @test listed[3].origin["path"] == abspath(cfg1)

            opt_layer = kernel.settings_source_add_json!(sim, cfg_optional; name = :opt1, after = :run2, optional = true)
            @test opt_layer.name == :opt1
            @test !haskey(opt_layer.data, "opt.value")
            kernel._write_json_file(cfg_optional, Dict("opt" => Dict("value" => 99)))
            kernel.settings_source_reload!(sim, :opt1)
            @test kernel.get_setting(sim, "opt.value") == 99

            kernel._write_json_file(cfg2, Dict("run" => Dict("beta" => 220)))
            kernel.settings_source_reload!(sim, :run2)
            @test kernel.get_setting(sim, "run.beta") == 220

            kernel.settings_source_remove!(sim, :run1)
            @test [layer.name for layer in sim.settings_stack.layers] == [:home, :project, :run2, :opt1, :env, :bootstrap, :script, :session]
            @test kernel.get_setting(sim, "run.alpha", :missing) == :missing
        end
    end

    @testset "settings reload! refreshes env and json sources" begin
        with_test_context() do ctx
            cfg = joinpath(ctx[:root_path], "reload.json")
            kernel._write_json_file(cfg, Dict("reload" => Dict("json" => "v1")))

            sim = kernel._get_sim()
            kernel.settings_source_add_json!(sim, cfg; name = :reloadfile)

            withenv("SIMULEOS_RELOAD_ENV" => "v1") do
                kernel.settings_reload!(sim)
                @test kernel.get_setting(sim, "reload.env") == "v1"
                @test kernel.get_setting(sim, "reload.json") == "v1"

                kernel._write_json_file(cfg, Dict("reload" => Dict("json" => "v2")))
                withenv("SIMULEOS_RELOAD_ENV" => "v2") do
                    kernel.settings_reload!(sim)
                    @test kernel.get_setting(sim, "reload.env") == "v2"
                    @test kernel.get_setting(sim, "reload.json") == "v2"
                end
            end
        end
    end

    @testset "settings explain reports layered candidates and winner" begin
        with_test_context() do ctx
            home_settings_path = joinpath(ctx[:home_path], kernel.SETTINGS_JSON)
            project_settings_path = kernel.settings_json_path(kernel._simuleos_dir(ctx[:project_path]))
            kernel._write_json_file(home_settings_path, Dict("demo.key" => "home"))
            kernel._write_json_file(project_settings_path, Dict("demo.key" => "project"))

            cfg = joinpath(ctx[:root_path], "explain.json")
            kernel._write_json_file(cfg, Dict("demo" => Dict("key" => "json")))

            withenv("SIMULEOS_DEMO_KEY" => "env") do
                kernel.sim_reset!()
                kernel.sim_init!(
                    bootstrap = Dict{String, Any}(
                        "project.root" => ctx[:project_path],
                        "home.path" => ctx[:home_path],
                        "demo.key" => "bootstrap",
                    ),
                )
                sim = kernel._get_sim()
                kernel.settings_source_add_json!(sim, cfg; name = :run1)

                ex = kernel.settings_explain(sim, "demo.key")
                @test ex.found == true
                @test ex.layer == :effective
                @test ex.winner_layer == :bootstrap
                @test ex.value == "bootstrap"
                @test [c.layer for c in ex.candidates] == [:home, :project, :run1, :env, :bootstrap]
                @test ex.candidates[3].kind == :json_file

                ex_run1 = kernel.settings_explain(sim, "demo.key"; layer = :run1)
                @test ex_run1.found == true
                @test ex_run1.winner_layer == :run1
                @test ex_run1.value == "json"
                @test length(ex_run1.candidates) == 1

                ex_missing = kernel.settings_explain(sim, "missing.key")
                @test ex_missing.found == false
                @test isnothing(ex_missing.winner_layer)
                @test isempty(ex_missing.candidates)
            end
        end
    end

    @testset "session settings use shared :session layer and reset on session.init" begin
        with_test_context() do _
            wsmod = Simuleos.WorkSession

            @simos session.init("phase3-session-a")
            sim = kernel._get_sim()
            ws = sim.worksession
            @test !isnothing(ws)

            kernel.settings_layer_set!(sim, :script, "phase3.script.keep", 100)
            @test kernel.get_setting(sim, "phase3.script.keep") == 100

            wsmod.session_setting!(ws, "phase3.session.temp", 200)
            @test wsmod.session_setting(ws, "phase3.session.temp") == 200
            ex1 = kernel.settings_explain(sim, "phase3.session.temp")
            @test ex1.found == true
            @test ex1.winner_layer == :session

            @simos session.close()
            @simos session.init("phase3-session-b")
            sim2 = kernel._get_sim()
            ws2 = sim2.worksession
            @test !isnothing(ws2)
            @test ws2 !== ws

            # Session layer resets on session switch/init.
            @test wsmod.session_setting(ws2, "phase3.session.temp", :missing) == :missing
            @test kernel.get_setting(sim2, "phase3.session.temp", :missing) == :missing

            # Script layer persists across session switches.
            @test kernel.get_setting(sim2, "phase3.script.keep") == 100

            ex2 = kernel.settings_explain(sim2, "phase3.session.temp")
            @test ex2.found == false
            @test isempty(ex2.candidates)
        end
    end
end
