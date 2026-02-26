@testset "CLI Args Settings Layer" begin
    Kernel = Simuleos.Kernel

    @testset "_coerce_cli_value type coercion" begin
        @test Kernel._coerce_cli_value("true") === true
        @test Kernel._coerce_cli_value("false") === false
        @test Kernel._coerce_cli_value("True") === true
        @test Kernel._coerce_cli_value("FALSE") === false
        @test Kernel._coerce_cli_value("nothing") === nothing

        @test Kernel._coerce_cli_value("42") === 42
        @test Kernel._coerce_cli_value("-7") === -7
        @test Kernel._coerce_cli_value("0") === 0

        @test Kernel._coerce_cli_value("3.14") === 3.14
        @test Kernel._coerce_cli_value("0.5") === 0.5
        @test Kernel._coerce_cli_value("-1.5") === -1.5

        @test Kernel._coerce_cli_value("hello") == "hello"
        @test Kernel._coerce_cli_value("") == ""
        @test Kernel._coerce_cli_value("path/to/file") == "path/to/file"
    end

    @testset "parse_cli_args --set key=value" begin
        args = ["--set", "run.alpha=0.5", "--set", "run.beta=hello"]
        result = Kernel.parse_cli_args(args)
        @test result["run.alpha"] === 0.5
        @test result["run.beta"] == "hello"
    end

    @testset "parse_cli_args --set=key=value compact form" begin
        args = ["--set=run.gamma=true", "--set=run.delta=42"]
        result = Kernel.parse_cli_args(args)
        @test result["run.gamma"] === true
        @test result["run.delta"] === 42
    end

    @testset "parse_cli_args --config loads JSON file" begin
        mktempdir() do tmpdir
            config_path = joinpath(tmpdir, "config.json")
            open(config_path, "w") do io
                write(io, """{"model":{"lr":0.001,"epochs":100},"data.path":"/data/train"}""")
            end

            args = ["--config", config_path]
            result = Kernel.parse_cli_args(args)
            @test result["model.lr"] === 0.001
            @test result["model.epochs"] === 100
            @test result["data.path"] == "/data/train"
        end
    end

    @testset "parse_cli_args --config=path compact form" begin
        mktempdir() do tmpdir
            config_path = joinpath(tmpdir, "config.json")
            open(config_path, "w") do io
                write(io, """{"x":1}""")
            end

            args = ["--config=$(config_path)"]
            result = Kernel.parse_cli_args(args)
            @test result["x"] === 1
        end
    end

    @testset "parse_cli_args skips unrecognized args" begin
        args = ["script.jl", "--set", "key=value", "--verbose", "other"]
        result = Kernel.parse_cli_args(args)
        @test length(result) == 1
        @test result["key"] == "value"
    end

    @testset "parse_cli_args mixed --set and --config" begin
        mktempdir() do tmpdir
            config_path = joinpath(tmpdir, "config.json")
            open(config_path, "w") do io
                write(io, """{"base.lr":0.01}""")
            end

            args = ["--config", config_path, "--set", "base.lr=0.001"]
            result = Kernel.parse_cli_args(args)
            # --set comes after --config, so it overrides
            @test result["base.lr"] === 0.001
        end
    end

    @testset "parse_cli_args error on missing value" begin
        @test_throws ErrorException Kernel.parse_cli_args(["--set"])
        @test_throws ErrorException Kernel.parse_cli_args(["--set", "noequals"])
        @test_throws ErrorException Kernel.parse_cli_args(["--config"])
    end

    @testset "settings_source_add_args! integrates with stack" begin
        with_test_context() do ctx
            sim = Kernel._get_sim()

            args = ["--set", "run.alpha=0.5", "--set", "run.seed=42"]
            layer = Kernel.settings_source_add_args!(sim, args)

            @test layer.name == :cli
            @test layer.kind == :cli
            @test layer.data["run.alpha"] === 0.5
            @test layer.data["run.seed"] === 42

            # CLI should override lower layers
            Kernel.settings_layer_set!(sim, :script, "run.alpha", 999.0)
            # But cli is inserted after :env, before :bootstrap/:script/:session
            # So :script (higher priority) should win
            val = Kernel.get_setting(sim, "run.alpha")
            @test val === 999.0

            # CLI should override :env and below
            val_seed = Kernel.get_setting(sim, "run.seed")
            @test val_seed === 42
        end
    end

    @testset "settings_source_add_args! merges on repeated calls" begin
        with_test_context() do ctx
            sim = Kernel._get_sim()

            Kernel.settings_source_add_args!(sim, ["--set", "a=1"])
            Kernel.settings_source_add_args!(sim, ["--set", "b=2"])

            stack = Kernel._settings_stack_required(sim)
            cli_layer = Kernel._settings_stack_layer(stack, :cli)
            @test cli_layer.data["a"] === 1
            @test cli_layer.data["b"] === 2
        end
    end

    @testset "layer priority: home < project < json_file < env < cli < bootstrap < script < session" begin
        with_test_context() do ctx
            sim = Kernel._get_sim()

            # Set in :env (lower than :cli)
            Kernel.settings_layer_set!(sim, :bootstrap, "test.priority", "bootstrap")
            Kernel.settings_source_add_args!(sim, ["--set", "test.priority=cli"])

            # :bootstrap is higher priority than :cli, so bootstrap wins
            val = Kernel.get_setting(sim, "test.priority")
            @test val == "bootstrap"

            # But if we set in env and cli, cli wins
            stack = Kernel._settings_stack_required(sim)
            env_layer = Kernel._settings_stack_layer(stack, :env)
            env_layer.data["test.envkey"] = "from_env"
            Kernel._settings_stack_rebuild!(stack)

            Kernel.settings_source_add_args!(sim, ["--set", "test.envkey=from_cli"])
            val2 = Kernel.get_setting(sim, "test.envkey")
            @test val2 == "from_cli"
        end
    end
end
