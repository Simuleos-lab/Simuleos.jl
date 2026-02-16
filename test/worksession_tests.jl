using Test
using Simuleos
using UUIDs

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
end
