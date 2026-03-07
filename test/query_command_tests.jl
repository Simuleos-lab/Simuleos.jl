using Test

@testset "@simos tapes.query command" begin

    # -- Setup: use the test sandbox from test-init.jl --
    # Record some data to query against
    @simos session.init("query-test-session")

    x = 42
    y = 3.14
    name = "test"

    @simos rec.meta(step = 1, phase = "setup")
    @simos rec.capture("summary")
    @simos rec.commit("query.test.summary")

    for i in 1:3
        x = i * 10
        @simos rec.meta(step = i, phase = "loop")
        @simos rec.capture("sample")
        @simos rec.commit("query.test.sample")
    end

    @simos session.close("query.test")

    # -- Test: query commits --
    @testset "query commits" begin
        results = @simos tapes.query(; class = "rec.capture_commit", session = "query-test-session")
        @test length(results) == 4  # 1 summary + 3 samples
        @test all(r -> r isa Simuleos.Kernel.RecCaptureCommitV1, results)
    end

    @testset "query commits by label" begin
        results = @simos tapes.query(; class = "rec.capture_commit", session = "query-test-session", commit_label = "query.test.sample")
        @test length(results) == 3
        @test all(r -> r.label == "query.test.sample", results)
    end

    @testset "query commits latest" begin
        results = @simos tapes.query(; class = "rec.capture_commit", session = "query-test-session", latest = true)
        @test length(results) == 1
        @test results[1].label == "query.test.sample"
    end

    @testset "query commits with limit" begin
        results = @simos tapes.query(; class = "rec.capture_commit", session = "query-test-session", limit = 2)
        @test length(results) == 2
    end

    # -- Test: query scopes --
    @testset "query scopes" begin
        results = @simos tapes.query(; class = "snap.scope", session = "query-test-session")
        @test length(results) == 4
        @test all(r -> r isa Simuleos.Kernel.SnapScopeV1, results)
    end

    @testset "query scopes by scope_label" begin
        results = @simos tapes.query(; class = "snap.scope", session = "query-test-session", scope_label = "sample")
        @test length(results) == 3
        @test all(r -> "sample" in r.labels, results)
    end

    @testset "query scopes by commit_label" begin
        results = @simos tapes.query(; class = "snap.scope", session = "query-test-session", commit_label = "query.test.summary")
        @test length(results) == 1
        @test "summary" in results[1].labels
    end

    @testset "query scopes latest" begin
        results = @simos tapes.query(; class = "snap.scope", session = "query-test-session", latest = true)
        @test length(results) == 1
        @test "sample" in results[1].labels
    end

    # -- Test: JMESPath where filter --
    @testset "query with JMESPath where" begin
        # Filter commits using JMESPath predicate on raw dict
        # (where expression is evaluated per-record as a boolean predicate)
        results = @simos tapes.query(;
            class = "rec.capture_commit",
            session = "query-test-session",
            where = "commit_label == 'query.test.summary'",
        )
        @test length(results) == 1
        @test results[1].label == "query.test.summary"
    end

    # -- Test: no class filter returns all record types --
    @testset "no class filter returns all" begin
        results = @simos tapes.query(; session = "query-test-session")
        # With no class filter, returns both commits and scopes
        @test length(results) >= 4
        has_commits = any(r -> r isa Simuleos.Kernel.RecCaptureCommitV1, results)
        has_scopes = any(r -> r isa Simuleos.Kernel.SnapScopeV1, results)
        @test has_commits
        @test has_scopes
    end

    # -- Test: no results --
    @testset "no results returns empty" begin
        results = @simos tapes.query(; class = "rec.capture_commit", session = "query-test-session", commit_label = "nonexistent")
        @test isempty(results)
    end

end
