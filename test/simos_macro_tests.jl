using Test
using Simuleos
using UUIDs

@testset "@simos dispatch macro" begin
    kernel = Simuleos.Kernel
    wsmod = Simuleos.WorkSession

    @testset "unknown verb errors with valid verb list" begin
        err = try
            Base.macroexpand(@__MODULE__, :(Simuleos.@simos bogus))
            nothing
        catch e
            e
        end
        @test err !== nothing
        msg = string(err)
        @test occursin("Unknown @simos verb", msg)
        @test occursin("init", msg)
        @test occursin("store", msg)
        @test occursin("remember", msg)
    end

    @testset "non-symbol verb errors" begin
        @test_throws ErrorException Base.macroexpand(
            @__MODULE__,
            :(Simuleos.@simos "not_a_symbol")
        )
    end

    @testset "@simos init round-trip" begin
        with_test_context() do _
            @simos init ("simos-init-" * string(uuid4()))
            ws = kernel._get_sim().worksession
            @test !isnothing(ws)
            @test startswith(ws.labels[1], "simos-init-")
        end
    end

    @testset "@simos store / hash / inline" begin
        with_test_context() do _
            @simos init ("simos-storage-" * string(uuid4()))
            ws = kernel._get_sim().worksession

            @simos store a b
            @test :a in ws.stage.blob_vars
            @test :b in ws.stage.blob_vars

            @simos hash c d
            @test :c in ws.stage.hash_vars
            @test :d in ws.stage.hash_vars

            @simos inline e f
            @test :e in ws.stage.inline_vars
            @test :f in ws.stage.inline_vars
        end
    end

    @testset "@simos meta" begin
        with_test_context() do _
            @simos init ("simos-meta-" * string(uuid4()))
            ws = kernel._get_sim().worksession

            @simos meta step=1 phase="training"
            @test ws.stage.meta_buffer[:step] == 1
            @test ws.stage.meta_buffer[:phase] == "training"
        end
    end

    @testset "@simos capture produces scope with source info" begin
        with_test_context() do _
            @simos init ("simos-capture-" * string(uuid4()))
            ws = kernel._get_sim().worksession

            let x = 42, y = "hello"
                @simos capture "test-scope"
            end

            @test length(ws.stage.captures) == 1
            scope = ws.stage.captures[1]
            @test "test-scope" in scope.labels
            @test haskey(scope.metadata, :src_file)
            @test haskey(scope.metadata, :src_line)
        end
    end

    @testset "@simos commit" begin
        with_test_context() do _
            simos2 = kernel._get_sim()
            proj2 = kernel.sim_project(simos2)

            @simos init ("simos-commit-" * string(uuid4()))
            ws = kernel._get_sim().worksession

            let x = 1
                @simos capture "s1"
            end
            @simos commit "c1"

            tape = kernel.TapeIO(kernel.tape_path(proj2, ws.session_id))
            commits = collect(kernel.iterate_tape(tape))
            @test length(commits) == 1
            @test commits[1].commit_label == "c1"
        end
    end

    @testset "@simos batch_commit and finalize" begin
        with_test_context() do _
            simos2 = kernel._get_sim()
            proj2 = kernel.sim_project(simos2)

            @simos init ("simos-batch-" * string(uuid4()))
            ws = kernel._get_sim().worksession

            let x = 1
                @simos capture "s1"
            end
            @simos batch_commit "bc1"
            @test length(ws.pending_commits) == 1

            let x = 2
                @simos capture "s2"
            end
            result = @simos finalize "tail"
            @test result.queued_tail_commit == true
            @test isempty(ws.pending_commits)

            tape = kernel.TapeIO(kernel.tape_path(proj2, ws.session_id))
            commits = collect(kernel.iterate_tape(tape))
            @test [c.commit_label for c in commits] == ["bc1", "tail"]
        end
    end

    @testset "@simos ctx_hash" begin
        with_test_context() do _
            @simos init ("simos-ctx-" * string(uuid4()))
            ws = kernel._get_sim().worksession

            x = 10
            y = "test"
            h = @simos ctx_hash "label" x y tol=1e-3
            @test h isa String
            @test length(h) == 40
            @test ws.context_hash_reg["label"] == h
        end
    end

    @testset "@simos remember all forms" begin
        with_test_context() do _
            @simos init ("simos-remember-" * string(uuid4()))
            x = 1
            h = @simos ctx_hash "key" x

            # assign form
            calls = Ref(0)
            s1 = @simos remember h a = begin
                calls[] += 1
                42
            end
            @test s1 == :miss
            @test a == 42

            a = -1
            s2 = @simos remember h a = begin
                calls[] += 1
                99
            end
            @test s2 == :hit
            @test a == 42
            @test calls[] == 1

            # block form
            calls_b = Ref(0)
            s3 = @simos remember h b begin
                calls_b[] += 1
                b = 100
            end
            @test s3 == :miss
            @test b == 100

            # tuple target
            calls_t = Ref(0)
            s4 = @simos remember h (p, q) = begin
                calls_t[] += 1
                (7, 8)
            end
            @test s4 == :miss
            @test (p, q) == (7, 8)

            # extra keys
            calls_e = Ref(0)
            s5 = @simos remember h (metric="A",) score = begin
                calls_e[] += 1
                99
            end
            @test s5 == :miss
            @test score == 99

            score = -1
            s6 = @simos remember h (metric="A",) score = begin
                calls_e[] += 1
                0
            end
            @test s6 == :hit
            @test score == 99
            @test calls_e[] == 1
        end
    end
end
