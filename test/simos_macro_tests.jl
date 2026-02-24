using Test
using Simuleos
using UUIDs

@testset "@simos dispatch macro" begin
    kernel = Simuleos.Kernel
    wsmod = Simuleos.WorkSession

    @testset "unknown command errors with valid command list" begin
        err = try
            Base.macroexpand(@__MODULE__, :(Simuleos.@simos foo.bar()))
            nothing
        catch e
            e
        end
        @test err !== nothing
        msg = string(err)
        @test occursin("Unknown @simos command", msg)
        @test occursin("session.init", msg)
        @test occursin("cache.remember", msg)
    end

    @testset "non-call syntax errors" begin
        @test_throws ErrorException Base.macroexpand(
            @__MODULE__,
            :(Simuleos.@simos "not_a_symbol")
        )
        @test_throws ErrorException Base.macroexpand(
            @__MODULE__,
            :(Simuleos.@simos bogus)
        )
    end

    @testset "call-style dotted commands" begin
        err = try
            Base.macroexpand(@__MODULE__, :(Simuleos.@simos foo.bar()))
            nothing
        catch e
            e
        end
        @test err !== nothing
        msg = string(err)
        @test occursin("Unknown @simos command", msg)
        @test occursin("session.init", msg)
        @test occursin("cache.remember", msg)

        with_test_context() do _
            proj0 = @simos project.current()
            @test proj0 === kernel.sim_project()

            blob_key = ("simos-blob-meta", string(uuid4()))
            blob_ref_obj = kernel.blob_write(kernel._get_sim(), blob_key, Dict("x" => 1))

            meta_by_ref = @simos blob.meta(blob_ref_obj)
            @test meta_by_ref isa Dict
            @test meta_by_ref["type"] == "blob_record"
            @test meta_by_ref["blob_hash"] == blob_ref_obj.hash

            meta_by_hash = @simos blob.meta(blob_ref_obj.hash)
            @test meta_by_hash["blob_hash"] == blob_ref_obj.hash

            meta_by_key = @simos blob.meta(blob_key)
            @test meta_by_key["blob_hash"] == blob_ref_obj.hash

            @test isnothing(@simos blob.meta("0000000000000000000000000000000000000000"))

            @simos session.init("simos-callstyle-" * string(uuid4()))
            ws = kernel._get_sim().worksession
            @test !isnothing(ws)

            @simos stage.blob(a, b)
            @simos stage.hash(c, d)
            @simos stage.inline(e, f)
            @simos stage.meta(step = 1, phase = "call-style")
            @test :a in ws.stage.blob_vars
            @test :d in ws.stage.hash_vars
            @test :f in ws.stage.inline_vars
            @test ws.stage.meta_buffer[:phase] == "call-style"

            let local_x = 7
                @simos scope.capture("call-style-scope")
            end
            @test length(ws.stage.captures) == 1

            x = 10
            y = "test"
            h = @simos cache.key("label", x, y, tol = 1e-3)
            @test h isa String
            @test ws.context_hash_reg["label"] == h

            calls = Ref(0)
            s1 = @simos cache.remember(h, z; metric = "A") do
                calls[] += 1
                42
            end
            z = -1
            s2 = @simos cache.remember(h, z; metric = "A") do
                calls[] += 1
                99
            end
            @test s1 == :miss
            @test s2 == :hit
            @test z == 42
            @test calls[] == 1

            st = @simos cache.remember(h, (p, q); metric = "B") do
                (1, 2)
            end
            @test st == :miss
            @test (p, q) == (1, 2)
        end
    end

    @testset "call-style system.init is engine-only" begin
        @test_throws ErrorException Base.macroexpand(
            @__MODULE__,
            :(Simuleos.@simos session.init("x"; reinit = true))
        )
        @test_throws ErrorException Base.macroexpand(
            @__MODULE__,
            :(Simuleos.@simos system.init("x"))
        )

        root = mktempdir()
        try
            kernel.sim_reset!()
            @simos system.init(; reinit = true, sandbox = (root = root, cleanup_on_reset = false))
            sim = kernel._get_sim()
            @test !isnothing(sim)
            @test isnothing(sim.worksession)
            @test !isnothing(sim.sandbox)

            @simos session.init("simos-call-init")
            ws = kernel._get_sim().worksession
            @test !isnothing(ws)
            @test ws.labels[1] == "simos-call-init"

            @simos system.reset()
            @test isnothing(kernel._get_sim_or_nothing())
        finally
            kernel.sim_reset!()
            isdir(root) && rm(root; recursive = true, force = true)
        end
    end

    @testset "@simos system.init + session.init round-trip" begin
        with_test_context() do _
            kernel.sim_reset!()
            @simos system.init()
            @test !isnothing(kernel._get_sim())
            @test isnothing(kernel._get_sim().worksession)

            @simos session.init("simos-init-" * string(uuid4()))
            ws = kernel._get_sim().worksession
            @test !isnothing(ws)
            @test startswith(ws.labels[1], "simos-init-")
        end
    end

    @testset "@simos stage.blob / stage.hash / stage.inline" begin
        with_test_context() do _
            @simos session.init("simos-storage-" * string(uuid4()))
            ws = kernel._get_sim().worksession

            @simos stage.blob(a, b)
            @test :a in ws.stage.blob_vars
            @test :b in ws.stage.blob_vars

            @simos stage.hash(c, d)
            @test :c in ws.stage.hash_vars
            @test :d in ws.stage.hash_vars

            @simos stage.inline(e, f)
            @test :e in ws.stage.inline_vars
            @test :f in ws.stage.inline_vars
        end
    end

    @testset "@simos stage.meta" begin
        with_test_context() do _
            @simos session.init("simos-meta-" * string(uuid4()))
            ws = kernel._get_sim().worksession

            @simos stage.meta(step=1, phase="training")
            @test ws.stage.meta_buffer[:step] == 1
            @test ws.stage.meta_buffer[:phase] == "training"
        end
    end

    @testset "@simos scope.capture produces scope with source info" begin
        with_test_context() do _
            @simos session.init("simos-capture-" * string(uuid4()))
            ws = kernel._get_sim().worksession

            let x = 42, y = "hello"
                @simos scope.capture("test-scope")
            end

            @test length(ws.stage.captures) == 1
            scope = ws.stage.captures[1]
            @test "test-scope" in scope.labels
            @test haskey(scope.metadata, :src_file)
            @test haskey(scope.metadata, :src_line)
        end
    end

    @testset "@simos session.commit" begin
        with_test_context() do _
            simos2 = kernel._get_sim()
            proj2 = kernel.sim_project(simos2)

            @simos session.init("simos-commit-" * string(uuid4()))
            ws = kernel._get_sim().worksession

            let x = 1
                @simos scope.capture("s1")
            end
            @simos session.commit("c1")

            tape = kernel.TapeIO(kernel.tape_path(proj2, ws.session_id))
            commits = collect(kernel.iterate_tape(tape))
            @test length(commits) == 1
            @test commits[1].commit_label == "c1"
        end
    end

    @testset "@simos session.queue and session.close" begin
        with_test_context() do _
            simos2 = kernel._get_sim()
            proj2 = kernel.sim_project(simos2)

            @simos session.init("simos-batch-" * string(uuid4()))
            ws = kernel._get_sim().worksession

            let x = 1
                @simos scope.capture("s1")
            end
            @simos session.queue("bc1")
            @test length(ws.pending_commits) == 1

            let x = 2
                @simos scope.capture("s2")
            end
            result = @simos session.close("tail")
            @test result.queued_tail_commit == true
            @test isempty(ws.pending_commits)

            tape = kernel.TapeIO(kernel.tape_path(proj2, ws.session_id))
            commits = collect(kernel.iterate_tape(tape))
            @test [c.commit_label for c in commits] == ["bc1", "tail"]
        end
    end

    @testset "@simos cache.key" begin
        with_test_context() do _
            @simos session.init("simos-ctx-" * string(uuid4()))
            ws = kernel._get_sim().worksession

            x = 10
            y = "test"
            h = @simos cache.key("label", x, y, tol=1e-3)
            @test h isa String
            @test length(h) == 40
            @test ws.context_hash_reg["label"] == h
        end
    end

    @testset "@simos cache.remember all forms" begin
        with_test_context() do _
            @simos session.init("simos-remember-" * string(uuid4()))
            x = 1
            h = @simos cache.key("key", x)

            # do-block form
            calls = Ref(0)
            s1 = @simos cache.remember(h, a) do
                calls[] += 1
                42
            end
            @test s1 == :miss
            @test a == 42

            a = -1
            s2 = @simos cache.remember(h, a) do
                calls[] += 1
                99
            end
            @test s2 == :hit
            @test a == 42
            @test calls[] == 1

            # tuple target
            st = @simos cache.remember(h, (p, q)) do
                (7, 8)
            end
            @test st == :miss
            @test (p, q) == (7, 8)

            # extra keys
            calls_e = Ref(0)
            s5 = @simos cache.remember(h, score; metric="A") do
                calls_e[] += 1
                99
            end
            @test s5 == :miss
            @test score == 99

            score = -1
            s6 = @simos cache.remember(h, score; metric="A") do
                calls_e[] += 1
                0
            end
            @test s6 == :hit
            @test score == 99
            @test calls_e[] == 1
        end
    end
end
