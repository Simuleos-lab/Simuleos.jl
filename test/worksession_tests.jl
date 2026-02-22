using Test
using Simuleos
using UUIDs
using Dates

@testset "WorkSession lifecycle (Option A)" begin
    kernel = Simuleos.Kernel
    wsmod = Simuleos.WorkSession

    simos = kernel._get_sim()
    proj = kernel.sim_project(simos)

    @testset "resolve_session has no side effects" begin
        simos.worksession = nothing
        sid = uuid4()
        session_json = kernel.session_json_path(proj, sid)
        if isfile(session_json)
            rm(session_json; force=true)
        end

        ws = wsmod.resolve_session(simos, proj; session_id=sid, labels=["alpha"])
        @test ws.session_id == sid
        @test ws.labels == ["alpha"]
        @test isempty(ws.metadata)
        @test isnothing(simos.worksession)
        @test !isfile(session_json)
    end

    @testset "session_init! resolves, persists, and binds state" begin
        simos.worksession = nothing
        sid = uuid4()

        wsmod.session_init!(
            simos,
            proj;
            session_id=sid,
            labels=["beta"],
            script_path=@__FILE__
        )

        @test !isnothing(simos.worksession)
        @test simos.worksession.session_id == sid
        @test simos.worksession.labels == ["beta"]

        session_json = kernel.session_json_path(proj, sid)
        @test isfile(session_json)
        @test isdir(kernel._session_dir(proj.simuleos_dir, sid))
        @test isdir(kernel._tapes_dir(proj.simuleos_dir, sid))

        loaded = wsmod.resolve_session(simos, proj; session_id=sid, labels=["ignored"])
        @test loaded.session_id == sid
        @test loaded.labels == ["beta"]
        @test haskey(loaded.metadata, "script_path")
    end

    @testset "project scan and parse session files" begin
        @test isdefined(wsmod, :scan_session_files)
        @test !isdefined(wsmod, :proj_scan_session_files)

        scan_label = "scan-" * string(uuid4())
        sid = uuid4()
        session_json = kernel.session_json_path(proj, sid)
        mkpath(dirname(session_json))
        open(session_json, "w") do io
            kernel.JSON3.pretty(io, Dict(
                "session_id" => string(sid),
                "labels" => [scan_label, "extra"],
                "meta" => Dict("timestamp" => string(DateTime(2026, 1, 1, 0, 0, 0)))
            ))
        end

        raws = Dict{String, Any}[]
        wsmod.scan_session_files(raw -> push!(raws, raw), proj)
        filtered = [raw for raw in raws if get(raw, "labels", Any[]) isa AbstractVector &&
            !isempty(raw["labels"]) && string(raw["labels"][1]) == scan_label]
        @test length(filtered) == 1

        parsed = wsmod.parse_session(proj, filtered[1])
        @test parsed.session_id == sid
        @test parsed.labels[1] == scan_label
    end

    @testset "resolve_session(proj, label) picks newest match" begin
        label = "resolve-" * string(uuid4())
        sid_old = uuid4()
        sid_new = uuid4()

        old_json = kernel.session_json_path(proj, sid_old)
        new_json = kernel.session_json_path(proj, sid_new)
        mkpath(dirname(old_json))
        mkpath(dirname(new_json))

        open(old_json, "w") do io
            kernel.JSON3.pretty(io, Dict(
                "session_id" => string(sid_old),
                "labels" => [label, "old"],
                "meta" => Dict("timestamp" => string(DateTime(2026, 1, 1, 0, 0, 0)))
            ))
        end

        open(new_json, "w") do io
            kernel.JSON3.pretty(io, Dict(
                "session_id" => string(sid_new),
                "labels" => [label, "new"],
                "meta" => Dict("timestamp" => string(DateTime(2026, 1, 2, 0, 0, 0)))
            ))
        end

        resolved = wsmod.resolve_session(proj, label)
        @test resolved.session_id == sid_new
        @test resolved.labels == [label, "new"]
    end

    @testset "resolve_session(proj, label) creates new session when missing" begin
        label = "new-" * string(uuid4())
        resolved = wsmod.resolve_session(proj, label)
        @test resolved.labels == [label]
        @test !isfile(kernel.session_json_path(proj, resolved.session_id))
    end

    @testset "resolve_session(proj, label) rejects empty label" begin
        @test_throws ErrorException wsmod.resolve_session(proj, "   ")
    end

    @testset "scan fails on invalid session file content" begin
        sid = uuid4()
        bad_json = kernel.session_json_path(proj, sid)
        mkpath(dirname(bad_json))
        open(bad_json, "w") do io
            write(io, "{invalid")
        end

        try
            @test_throws Exception wsmod.scan_session_files(_ -> nothing, proj)
        finally
            rm(dirname(bad_json); recursive=true, force=true)
        end
    end

    @testset "macro init wrapper enforces string labels" begin
        @test_throws ErrorException wsmod.session_init_from_macro!(Any[1], @__FILE__, 1)
    end

    @testset "isdirty and active-session reinit guard" begin
        simos.worksession = wsmod.resolve_session(simos, proj; labels=["guard"])
        @test wsmod.isdirty(simos, simos.worksession) == false

        push!(simos.worksession.stage.captures, kernel.SimuleosScope())
        @test wsmod.isdirty(simos, simos.worksession) == true
        @test_throws ErrorException wsmod.session_init!(["another"], @__FILE__)

        empty!(simos.worksession.stage.captures)
        push!(simos.worksession.pending_commits, kernel.ScopeCommit("", Dict{String, Any}(), kernel.SimuleosScope[]))
        @test wsmod.isdirty(simos, simos.worksession) == true
    end

    @testset "global session_init! with explicit session_id bypasses label lookup" begin
        simos.worksession = nothing
        sid = uuid4()
        wsmod.session_init!(["label-a"], @__FILE__; session_id=sid)
        @test simos.worksession.session_id == sid
        @test simos.worksession.labels == ["label-a"]
    end

    @testset "@ctx_hash records named hashes from scope values" begin
        with_test_context() do _
            @session_init ("ctxhash-" * string(uuid4()))
            ws = kernel._get_sim().worksession
            @test !isnothing(ws)
            @test isempty(ws.context_hash_reg)

            x = 3
            y = "alpha"
            h1 = Simuleos.@ctx_hash "solver-input" x y tol=1e-6 mode="fast"
            @test h1 isa String
            @test length(h1) == 40
            @test ws.context_hash_reg["solver-input"] == h1

            h2 = Simuleos.@ctx_hash "solver-input" x y tol=1e-6 mode="fast"
            @test h2 == h1

            x = 4
            h3 = Simuleos.@ctx_hash "solver-input" x y tol=1e-6 mode="fast"
            @test h3 != h1
            @test ws.context_hash_reg["solver-input"] == h3

            h4 = Simuleos.@ctx_hash "alt-order" y x tol=1e-6 mode="fast"
            @test h4 isa String
            @test ws.context_hash_reg["alt-order"] == h4
        end
    end

    @testset "@ctx_hash requires active session" begin
        with_test_context() do _
            kernel._get_sim().worksession = nothing
            @test_throws ErrorException Simuleos.@ctx_hash "no-session" tol=1e-6
        end
    end

    @testset "remember! reuses blob-backed values by named ctx hash" begin
        with_test_context() do ctx
            @session_init ("cache-a-" * string(uuid4()))
            ws = kernel._get_sim().worksession
            @test !isnothing(ws)

            model = "iJO1366"
            eps = 1e-6
            solver = "HiGHS"
            @test isempty(ws.context_hash_reg)
            h = Simuleos.@ctx_hash "fva-inputs" model eps solver
            @test ws.context_hash_reg["fva-inputs"] == h

            calls = Ref(0)
            value1, status1 = Simuleos.remember!("fva"; ctx="fva-inputs", tags=["fva", "expensive"]) do
                calls[] += 1
                Dict("status" => "ok", "objective" => 0.92)
            end
            @test status1 == :miss
            @test calls[] == 1
            @test value1["status"] == "ok"

            value2, status2 = Simuleos.remember!("fva"; ctx="fva-inputs", tags=["fva", "expensive"]) do
                calls[] += 1
                Dict("status" => "ok", "objective" => 9.99)
            end
            @test status2 == :hit
            @test calls[] == 1
            @test value2 == value1

            kernel.sim_reset!()
            kernel.sim_init!(
                bootstrap = Dict{String, Any}(
                    "project.root" => ctx[:project_path],
                    "home.path" => ctx[:home_path],
                )
            )
            @session_init ("cache-b-" * string(uuid4()))
            model = "iJO1366"
            eps = 1e-6
            solver = "HiGHS"
            Simuleos.@ctx_hash "fva-inputs" model eps solver

            value3, status3 = Simuleos.remember!("fva"; ctx="fva-inputs") do
                calls[] += 1
                Dict("status" => "ok", "objective" => 7.77)
            end
            @test status3 == :hit
            @test calls[] == 1
            @test value3 == value1
        end
    end

    @testset "remember! supports explicit ctx_hash and validates inputs" begin
        with_test_context() do _
            @session_init ("cache-explicit-" * string(uuid4()))
            x = 10
            h = Simuleos.@ctx_hash "demo" x

            calls = Ref(0)
            v1, s1 = Simuleos.remember!("demo"; ctx_hash=h) do
                calls[] += 1
                x^2
            end
            v2, s2 = Simuleos.remember!("demo"; ctx_hash=h) do
                calls[] += 1
                x^3
            end
            @test (v1, s1) == (100, :miss)
            @test (v2, s2) == (100, :hit)
            @test calls[] == 1

            race_calls = Ref(0)
            race_ctx_extra = (metric="race",)
            v_race, s_race = Simuleos.remember!("demo"; ctx_hash=h, ctx_extra=race_ctx_extra) do
                race_calls[] += 1
                proj = kernel.sim_project(kernel._get_sim())
                race_ctx_hash = wsmod._ctx_hash_compose(h, race_ctx_extra)
                outcome = kernel.cache_store!(proj, "demo", race_ctx_hash, 111)
                @test outcome.status == :stored
                222
            end
            @test (v_race, s_race) == (111, :race_lost)
            @test race_calls[] == 1

            v3, s3 = Simuleos.remember!("demo"; ctx_hash=h, ctx_extra=(metric="cube",)) do
                calls[] += 1
                x^3
            end
            v4, s4 = Simuleos.remember!("demo"; ctx_hash=h, ctx_extra=(metric="cube",)) do
                calls[] += 1
                x^4
            end
            v5, s5 = Simuleos.remember!("demo"; ctx_hash=h, ctx_extra=(metric="square",)) do
                calls[] += 1
                x^2 + 1
            end
            @test (v3, s3) == (1000, :miss)
            @test (v4, s4) == (1000, :hit)
            @test (v5, s5) == (101, :miss)
            @test calls[] == 3

            @test_throws ErrorException Simuleos.remember!("demo"; ctx="demo", ctx_hash=h) do
                1
            end
            @test_throws ErrorException Simuleos.remember!("demo"; ctx="missing") do
                1
            end
        end
    end

    @testset "@remember macro supports single/tuple targets and assignment shorthand" begin
        with_test_context() do _
            @session_init ("remember-macro-" * string(uuid4()))

            model = "iJO1366"
            eps = 1e-6
            solver = "HiGHS"
            h = Simuleos.@ctx_hash "solver-inputs" model eps solver

            calls_a = Ref(0)
            status_a1 = Simuleos.@remember h a = begin
                calls_a[] += 1
                11
            end
            @test status_a1 == :miss
            @test a == 11

            a = -1
            status_a2 = Simuleos.@remember h a = begin
                calls_a[] += 1
                99
            end
            @test status_a2 == :hit
            @test a == 11
            @test calls_a[] == 1

            status_a_race = Simuleos.@remember h a_race = begin
                proj = kernel.sim_project(kernel._get_sim())
                ns = wsmod._remember_namespace(:a_race)
                outcome = kernel.cache_store!(proj, ns, string(h), 41)
                @test outcome.status == :stored
                99
            end
            @test status_a_race == :race_lost
            @test a_race == 41

            calls_b = Ref(0)
            status_b1 = Simuleos.@remember h b begin
                calls_b[] += 1
                b = a + 1
            end
            @test status_b1 == :miss
            @test b == 12

            b = -1
            status_b2 = Simuleos.@remember h b begin
                calls_b[] += 1
                b = 999
            end
            @test status_b2 == :hit
            @test b == 12
            @test calls_b[] == 1

            calls_tuple = Ref(0)
            status_t1 = Simuleos.@remember h (u, v) begin
                calls_tuple[] += 1
                u, v = (3, 4)
            end
            @test status_t1 == :miss
            @test (u, v) == (3, 4)

            u, v = (30, 40)
            status_t2 = Simuleos.@remember h (u, v) begin
                calls_tuple[] += 1
                u, v = (300, 400)
            end
            @test status_t2 == :hit
            @test (u, v) == (3, 4)
            @test calls_tuple[] == 1

            calls_tuple_assign = Ref(0)
            status_ta1 = Simuleos.@remember h (p, q) = begin
                calls_tuple_assign[] += 1
                (7, 8)
            end
            @test status_ta1 == :miss
            @test (p, q) == (7, 8)

            p, q = (70, 80)
            status_ta2 = Simuleos.@remember h (p, q) = begin
                calls_tuple_assign[] += 1
                (700, 800)
            end
            @test status_ta2 == :hit
            @test (p, q) == (7, 8)
            @test calls_tuple_assign[] == 1

            calls_partition = Ref(0)
            status_part_1 = Simuleos.@remember h (metric="A", fold=1) score = begin
                calls_partition[] += 1
                41
            end
            @test status_part_1 == :miss
            @test score == 41

            score = -1
            status_part_2 = Simuleos.@remember h (metric="A", fold=1) score = begin
                calls_partition[] += 1
                999
            end
            @test status_part_2 == :hit
            @test score == 41

            score = -1
            status_part_3 = Simuleos.@remember h (metric="B", fold=1) score = begin
                calls_partition[] += 1
                42
            end
            @test status_part_3 == :miss
            @test score == 42
            @test calls_partition[] == 2
        end
    end

    @testset "@remember macro checks miss-branch assignments" begin
        with_test_context() do _
            @session_init ("remember-check-" * string(uuid4()))
            x = 1
            h = Simuleos.@ctx_hash "check" x

            @test_throws ErrorException Simuleos.@remember h z begin
                nothing
            end

            @test_throws ErrorException begin
                Simuleos.@remember h (m, n) begin
                    m = 1
                end
            end
        end
    end

    @testset "@remember macro extra-key tuple requires key=value pairs" begin
        ex = :(Simuleos.@remember h (metric="A", fold=1) score = 1)
        expanded = Base.macroexpand(@__MODULE__, ex)
        @test expanded isa Expr

        @test_throws ErrorException Base.macroexpand(
            @__MODULE__,
            :(Simuleos.@remember h (metric="A", fold) score = 1)
        )

        @test_throws ErrorException Base.macroexpand(
            @__MODULE__,
            :(Simuleos.@remember h ("A", 1) score = 1)
        )
    end

    @testset "queued commits and session finalizer" begin
        with_test_context() do _
            simos2 = kernel._get_sim()
            proj2 = kernel.sim_project(simos2)

            @session_init ("queue-" * string(uuid4()))
            ws = kernel._get_sim().worksession
            @test !isnothing(ws)

            tape = kernel.TapeIO(kernel.tape_path(proj2, ws.session_id))
            @test isempty(collect(kernel.iterate_tape(tape)))

            let x = 1
                @scope_capture "s1"
            end
            c1 = wsmod.session_batch_commit("c1"; max_pending_commits=2)
            @test c1.commit_label == "c1"
            @test length(ws.pending_commits) == 1
            @test isempty(collect(kernel.iterate_tape(tape)))

            let x = 2
                @scope_capture "s2"
            end
            c2 = wsmod.session_batch_commit("c2"; max_pending_commits=2)
            @test c2.commit_label == "c2"
            @test isempty(ws.pending_commits)

            commits = collect(kernel.iterate_tape(tape))
            @test [c.commit_label for c in commits] == ["c1", "c2"]

            let x = 3
                @scope_capture "s3"
            end
            Simuleos.@session_batch_commit "c3"
            @test length(ws.pending_commits) == 1

            let x = 4
                @scope_capture "s4"
            end
            result = Simuleos.@session_finalize "tail"
            @test result.queued_tail_commit == true
            @test result.flushed_commits == 2
            @test isempty(ws.pending_commits)
            @test isempty(ws.stage.captures)

            commits = collect(kernel.iterate_tape(tape))
            @test [c.commit_label for c in commits] == ["c1", "c2", "c3", "tail"]
        end
    end

    @testset "queued commit flush trims flushed prefix on error (retry-safe)" begin
        with_test_context() do _
            simos2 = kernel._get_sim()
            proj2 = kernel.sim_project(simos2)

            @session_init ("queue-flush-failure-" * string(uuid4()))
            ws = kernel._get_sim().worksession
            @test !isnothing(ws)

            tape = kernel.TapeIO(kernel.tape_path(proj2, ws.session_id))
            @test isempty(collect(kernel.iterate_tape(tape)))

            let x = 1
                @scope_capture "s1"
            end
            wsmod.session_batch_commit("c1"; max_pending_commits=99)

            let x = 2
                @scope_capture "s2"
            end
            wsmod.session_batch_commit("c2"; max_pending_commits=99)

            let x = 3
                @scope_capture "s3"
            end
            wsmod.session_batch_commit("c3"; max_pending_commits=99)

            @test [c.commit_label for c in ws.pending_commits] == ["c1", "c2", "c3"]

            injected_calls = Ref(0)
            failing_writer = function (t, commit)
                injected_calls[] += 1
                if injected_calls[] == 2
                    error("injected flush failure")
                end
                kernel.commit_to_tape!(t, commit)
            end

            @test_throws ErrorException wsmod._flush_pending_commits!(proj2, ws; commit_writer=failing_writer)

            @test [c.commit_label for c in ws.pending_commits] == ["c2", "c3"]
            commits_after_fail = collect(kernel.iterate_tape(tape))
            @test [c.commit_label for c in commits_after_fail] == ["c1"]

            flushed_retry = wsmod._flush_pending_commits!(proj2, ws)
            @test flushed_retry == 2
            @test isempty(ws.pending_commits)

            commits_after_retry = collect(kernel.iterate_tape(tape))
            @test [c.commit_label for c in commits_after_retry] == ["c1", "c2", "c3"]
        end
    end

    @testset "session_init warns when switching from unfinalized session" begin
        with_test_context() do _
            expected_init_line = (@__LINE__) + 1
            @session_init ("warn-a-" * string(uuid4()))
            ws = kernel._get_sim().worksession
            @test ws.is_finalized == false
            @test haskey(ws.metadata, kernel.SESSION_META_INIT_FILE_KEY)
            @test haskey(ws.metadata, kernel.SESSION_META_INIT_LINE_KEY)
            @test basename(String(ws.metadata[kernel.SESSION_META_INIT_FILE_KEY])) == basename(@__FILE__)
            @test Int(ws.metadata[kernel.SESSION_META_INIT_LINE_KEY]) == expected_init_line

            @test_logs (:warn, r"initialized at .*:") wsmod.session_init!(["warn-b-" * string(uuid4())], @__FILE__)
            ws2 = kernel._get_sim().worksession
            @test ws2.labels[1] != ws.labels[1]
            @test ws2.is_finalized == false
        end
    end

    @testset "session_init does not warn after explicit finalization" begin
        with_test_context() do _
            @session_init ("final-a-" * string(uuid4()))
            wsmod.session_finalize()
            ws = kernel._get_sim().worksession
            @test ws.is_finalized == true

            @test_logs wsmod.session_init!(["final-b-" * string(uuid4())], @__FILE__)
        end
    end
end
