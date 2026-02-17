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
        @test isempty(ws.meta)
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
        @test isdir(kernel._scopetapes_dir(proj.simuleos_dir, sid))

        loaded = wsmod.resolve_session(simos, proj; session_id=sid, labels=["ignored"])
        @test loaded.session_id == sid
        @test loaded.labels == ["beta"]
        @test haskey(loaded.meta, "script_path")
    end

    @testset "project scan and parse session files" begin
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
        wsmod.proj_scan_session_files(raw -> push!(raws, raw), proj)
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
            @test_throws Exception wsmod.proj_scan_session_files(_ -> nothing, proj)
        finally
            rm(dirname(bad_json); recursive=true, force=true)
        end
    end

    @testset "macro init wrapper enforces string labels" begin
        @test_throws ErrorException wsmod.session_init_from_macro!(Any[1], @__FILE__)
    end

    @testset "isdirty and active-session reinit guard" begin
        simos.worksession = wsmod.resolve_session(simos, proj; labels=["guard"])
        @test wsmod.isdirty(simos, simos.worksession) == false

        push!(simos.worksession.stage.captures, kernel.SimuleosScope())
        @test wsmod.isdirty(simos, simos.worksession) == true
        @test_throws ErrorException wsmod.session_init!(["another"], @__FILE__)
    end

    @testset "global session_init! with explicit session_id bypasses label lookup" begin
        simos.worksession = nothing
        sid = uuid4()
        wsmod.session_init!(["label-a"], @__FILE__; session_id=sid)
        @test simos.worksession.session_id == sid
        @test simos.worksession.labels == ["label-a"]
    end
end
