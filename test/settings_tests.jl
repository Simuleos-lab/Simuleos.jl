let
    kernel = Simuleos.Kernel

    @testset "pre-init bootstrap SimOs supports settings before sim_init!" begin
        root = mktempdir()
        proj_root = joinpath(root, "proj")
        home_root = joinpath(root, "home")
        mkpath(proj_root)
        mkpath(home_root)

        try
            kernel.sim_reset!()

            sim_boot = kernel._get_simos_unsafe()
            @test sim_boot.lifecycle == :bootstrap
            @test isnothing(kernel._get_simos_or_nothing())
            @test_throws ErrorException kernel._get_simos()

            @simos settings.set("preinit.demo", 11)
            @test (@simos settings.get("preinit.demo")) == 11
            @test any(x -> x.name == :env, @simos settings.layers())

            cfg = joinpath(root, "preinit.json")
            kernel._write_json_file(cfg, Dict("x" => 1))
            @test_throws ErrorException @simos settings.source.add_json(cfg)

            kernel.sim_init!(project_root = proj_root, home_path = home_root)
            sim_ready = kernel._get_simos()
            @test sim_ready.lifecycle == :ready
            @test kernel.settings(sim_ready, "preinit.demo") == 11
        finally
            kernel.sim_reset!()
            isdir(root) && rm(root; recursive = true, force = true)
        end
    end

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
                    project_root = ctx[:project_path],
                    home_path = ctx[:home_path],
                    var"demo.key" = "bootstrap",
                    var"bootstrap.only" = 3,
                )

                sim = kernel._get_simos()
                @test !isnothing(sim.settings_stack)
                @test [layer.name for layer in sim.settings_stack.layers] == [:defaults, :home, :project, :env, :runtime, :script, :session]

                @test kernel.settings(sim, "demo.key") == "bootstrap"
                @test kernel.settings(sim, "home.only") == 1
                @test kernel.settings(sim, "project.only") == 2
                @test kernel.settings(sim, "SIMULEOS_ENV_ONLY") == "envv"
                @test kernel.settings(sim, "bootstrap.only") == 3
            end
        end
    end

    @testset "settings auto-builds settings stack when missing" begin
        sim = kernel.SimOs(; runtime_settings = Dict{String, Any}("demo.key" => "boot"))
        @test isnothing(sim.settings_stack)
        @test kernel.settings(sim, "demo.key") == "boot"
        @test !isnothing(sim.settings_stack)
    end

    @testset "sim_init! supports package-module runtime setting project.root" begin
        with_test_context() do ctx
            pkg_parent = mktempdir()
            pkg_name = "TmpPkg" * replace(string(kernel.UUIDs.uuid4()), "-" => "")
            pkg_root = joinpath(pkg_parent, pkg_name)
            src_root = joinpath(pkg_root, "src")
            mkpath(src_root)
            write(
                joinpath(pkg_root, "Project.toml"),
                "name = \"$(pkg_name)\"\n" *
                "uuid = \"$(kernel.UUIDs.uuid4())\"\n" *
                "version = \"0.1.0\"\n",
            )
            write(joinpath(src_root, "$(pkg_name).jl"), "module $(pkg_name)\nend\n")

            pushfirst!(LOAD_PATH, pkg_root)
            try
                pkg_mod = Base.require(Main, Symbol(pkg_name))

                kernel.sim_reset!()
                kernel.sim_init!(
                    project_root = pkg_mod,
                    home_path = ctx[:home_path],
                )

                sim = kernel._get_simos()
                expected_root = abspath(pkgdir(pkg_mod))
                @test sim.project.root_path == expected_root
                @test sim.runtime_settings["project.root"] == expected_root
                @test kernel.settings(sim, "project.root") == expected_root
            finally
                popfirst!(LOAD_PATH)
                rm(pkg_parent; recursive = true, force = true)
            end
        end
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

            sim = kernel._get_simos()
            stack = sim.settings_stack
            @test !isnothing(stack)
            @test stack.effective_version == stack.version
            @test stack.effective_complete == false
            @test isempty(stack.effective)
            @test isempty(stack.effective_missing)

            @test kernel.settings(sim, "missing.key", :missing) == :missing
            @test "missing.key" in stack.effective_missing
            @test !haskey(stack.effective, "missing.key")
            @test stack.effective_complete == false

            @test kernel.settings(sim, "project.root") == ctx[:project_path]
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

            @test kernel.settings(sim, "lazy.value") == 10
            @test haskey(stack.effective, "lazy.value")
        end
    end

    @testset "settings sources add/remove/list/reload JSON layers" begin
        with_test_context() do ctx
            sim = kernel._get_simos()

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
            @test kernel.settings(sim, "run.alpha") == 11
            @test kernel.settings(sim, "demo.key") == "json1"
            @test [layer.name for layer in sim.settings_stack.layers] == [:defaults, :home, :project, :run1, :env, :runtime, :script, :session]

            layer2 = kernel.settings_source_add_json!(sim, cfg2; name = :run2, after = :run1)
            @test layer2.name == :run2
            @test kernel.settings(sim, "run.beta") == 22
            @test kernel.settings(sim, "demo.key") == "json2"
            @test [layer.name for layer in sim.settings_stack.layers] == [:defaults, :home, :project, :run1, :run2, :env, :runtime, :script, :session]

            listed = kernel.settings_source_list(sim)
            @test [entry.name for entry in listed] == [:defaults, :home, :project, :run1, :run2, :env, :runtime, :script, :session]
            listed_run1_idx = findfirst(entry -> entry.name == :run1, listed)
            @test !isnothing(listed_run1_idx)
            listed_run1 = listed[listed_run1_idx::Int]
            @test listed_run1.kind == :json_file
            @test listed_run1.origin["path"] == abspath(cfg1)

            opt_layer = kernel.settings_source_add_json!(sim, cfg_optional; name = :opt1, after = :run2, optional = true)
            @test opt_layer.name == :opt1
            @test !haskey(opt_layer.data, "opt.value")
            kernel._write_json_file(cfg_optional, Dict("opt" => Dict("value" => 99)))
            kernel.settings_source_reload_external!(sim, :opt1)
            @test kernel.settings(sim, "opt.value") == 99

            kernel._write_json_file(cfg2, Dict("run" => Dict("beta" => 220)))
            kernel.settings_source_reload_external!(sim, :run2)
            @test kernel.settings(sim, "run.beta") == 220

            kernel.settings_source_remove!(sim, :run1)
            @test [layer.name for layer in sim.settings_stack.layers] == [:defaults, :home, :project, :run2, :opt1, :env, :runtime, :script, :session]
            @test kernel.settings(sim, "run.alpha", :missing) == :missing
        end
    end

    @testset "settings reload! refreshes env and json sources" begin
        with_test_context() do ctx
            cfg = joinpath(ctx[:root_path], "reload.json")
            kernel._write_json_file(cfg, Dict("reload" => Dict("json" => "v1")))

            sim = kernel._get_simos()
            kernel.settings_source_add_json!(sim, cfg; name = :reloadfile)

            withenv("SIMULEOS_RELOAD_ENV" => "v1") do
                kernel.settings_reload_externals!(sim)
                @test kernel.settings(sim, "SIMULEOS_RELOAD_ENV") == "v1"
                @test kernel.settings(sim, "reload.json") == "v1"

                kernel._write_json_file(cfg, Dict("reload" => Dict("json" => "v2")))
                withenv("SIMULEOS_RELOAD_ENV" => "v2") do
                    kernel.settings_reload_externals!(sim)
                    @test kernel.settings(sim, "SIMULEOS_RELOAD_ENV") == "v2"
                    @test kernel.settings(sim, "reload.json") == "v2"
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
                    project_root = ctx[:project_path],
                    home_path = ctx[:home_path],
                    var"demo.key" = "bootstrap",
                )
                sim = kernel._get_simos()
                kernel.settings_source_add_json!(sim, cfg; name = :run1)

                ex = kernel.settings_explain(sim, "demo.key")
                @test ex.found == true
                @test ex.layer == :effective
                @test ex.winner_layer == :runtime
                @test ex.value == "bootstrap"
                @test [c.layer for c in ex.candidates] == [:home, :project, :run1, :runtime]
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
            sim = kernel._get_simos()
            ws = sim.worksession
            @test !isnothing(ws)

            kernel.settings_layer_set!(sim, :script, "phase3.script.keep", 100)
            @test kernel.settings(sim, "phase3.script.keep") == 100

            wsmod.session_setting!(ws, "phase3.session.temp", 200)
            @test wsmod.session_setting(ws, "phase3.session.temp") == 200
            ex1 = kernel.settings_explain(sim, "phase3.session.temp")
            @test ex1.found == true
            @test ex1.winner_layer == :session

            @simos session.close()
            @simos session.init("phase3-session-b")
            sim2 = kernel._get_simos()
            ws2 = sim2.worksession
            @test !isnothing(ws2)
            @test ws2 !== ws

            # Session layer resets on session switch/init.
            @test wsmod.session_setting(ws2, "phase3.session.temp", :missing) == :missing
            @test kernel.settings(sim2, "phase3.session.temp", :missing) == :missing

            # Script layer persists across session switches.
            @test kernel.settings(sim2, "phase3.script.keep") == 100

            ex2 = kernel.settings_explain(sim2, "phase3.session.temp")
            @test ex2.found == false
            @test isempty(ex2.candidates)
        end
    end

    @testset "settings registry is a strict resolver layer on top of default system" begin
        with_test_context() do _
            sim = kernel._get_simos()

            # Default system behavior for unregistered keys remains unchanged.
            kernel.settings_layer_set!(sim, :script, "registry.demo", "script-value")
            @test kernel.settings(sim, "registry.demo") == "script-value"

            # Registry hit with aliases but no custom resolve.priority -> delegate to default system on canonical key.
            entry_alias = kernel.settings_registry_register!(sim, "registry.demo", Dict(
                "alias" => ["registryDemo", "REGISTRY_DEMO"],
            ))
            @test entry_alias.canonical == "registry.demo"
            @test kernel.settings(sim, "registryDemo") == "script-value"
            @test kernel.settings(sim, "REGISTRY_DEMO") == "script-value"

            listed = kernel.settings_registry_list(sim)
            @test any(e -> e.canonical == "registry.demo", listed)

            # Registry hit + custom resolve.priority miss is a final miss (no fallback to default system).
            kernel.settings_layer_set!(sim, :script, "registry.strict", "script-only")
            kernel.settings_registry_register!(sim, "registry.strict", Dict(
                "alias" => ["registryStrict"],
                "resolve.priority" => Any[:env],
            ))
            @test kernel.settings(sim, "registryStrict", :missing) == :missing
            @test kernel.settings(sim, "registry.strict", :missing) == :missing
            ex_strict = kernel.settings_explain(sim, "registryStrict")
            @test ex_strict.found == false
            @test ex_strict.registry_hit == true

            # Custom source-priority resolution honors selector order.
            kernel.settings_layer_set!(sim, :script, "registry.priority", "script-priority")
            withenv("SIMULEOS_REGISTRY_PRIORITY" => "env-priority") do
                kernel.settings_reload_externals!(sim)

                kernel.settings_registry_register!(sim, "registry.priority", Dict(
                    "alias" => ["registryPriority", "SIMULEOS_REGISTRY_PRIORITY"],
                    "resolve.priority" => Any[:runtime, :env],
                ))
                @test kernel.settings(sim, "registryPriority") == "script-priority"

                kernel.settings_registry_register!(sim, "registry.priority", Dict(
                    "alias" => ["registryPriority", "SIMULEOS_REGISTRY_PRIORITY"],
                    "resolve.priority" => Any[:env, :runtime],
                ); replace = true)
                @test kernel.settings(sim, "registryPriority") == "env-priority"
                ex_priority = kernel.settings_explain(sim, "registryPriority")
                @test ex_priority.found == true
                @test ex_priority.winner_layer == :env
                @test ex_priority.registry_hit == true
            end

            @test kernel.settings_registry_unregister!(sim, "registry.demo") == true
            @test kernel.settings_registry_unregister!(sim, "registryDemo") == false
        end
    end
end
