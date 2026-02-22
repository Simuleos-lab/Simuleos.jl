import Dates
import UUIDs
using Test
import Simuleos

include(joinpath(@__DIR__, "..", "src", "SimulesCLI.jl"))

function _session_json(labels::Vector{String}, timestamp::Dates.DateTime, session_id::Base.UUID)
    return Dict(
        "session_id" => string(session_id),
        "labels" => labels,
        "meta" => Dict(
            "timestamp" => string(timestamp),
        ),
    )
end

@testset "Simules CLI stats" begin
    mktempdir() do root
        project_driver = Simuleos.Kernel.proj_init_at(root)

        sid_1 = UUIDs.uuid4()
        sid_2 = UUIDs.uuid4()
        ts_1 = Dates.DateTime("2026-02-20T08:00:00")
        ts_2 = Dates.DateTime("2026-02-20T10:00:00")

        Simuleos.Kernel._write_json_file(
            Simuleos.Kernel.session_json_path(project_driver, sid_1),
            _session_json(["train", "phase-a"], ts_1, sid_1),
        )
        Simuleos.Kernel._write_json_file(
            Simuleos.Kernel.session_json_path(project_driver, sid_2),
            _session_json(["eval"], ts_2, sid_2),
        )

        vars = Dict{Symbol, Simuleos.Kernel.ScopeVariable}()
        vars[:x] = Simuleos.Kernel.InlineScopeVariable(:local, "Int64", 7)
        vars[:dataset] = Simuleos.Kernel.BlobScopeVariable(:global, "Matrix{Float64}", Simuleos.Kernel.BlobRef("abc123"))
        vars[:builder] = Simuleos.Kernel.VoidScopeVariable(:global, "Function")

        scope = Simuleos.Kernel.SimuleosScope(
            ["scope-a"],
            vars,
            Dict{Symbol, Any}(),
        )
        commit = Simuleos.Kernel.ScopeCommit(
            "first-commit",
            Dict{String, Any}("step" => 1),
            [scope],
        )
        tape = Simuleos.Kernel.TapeIO(Simuleos.Kernel.tape_path(project_driver, sid_1))
        Simuleos.Kernel.commit_to_tape!(tape, commit)

        open(joinpath(Simuleos.Kernel.blobs_dir(project_driver.simuleos_dir), "abc123.jls"), "w") do io
            write(io, "blob-data")
        end

        stats = SimulesCLI.collect_project_stats(root)

        @test stats.session_count == 2
        @test stats.commit_count == 1
        @test stats.scope_count == 1
        @test stats.variable_count == 3
        @test stats.inline_variable_count == 1
        @test stats.blob_variable_count == 1
        @test stats.void_variable_count == 1
        @test stats.blob_file_count == 1
        @test !isnothing(stats.latest_session)
        @test stats.latest_session.session_id == sid_2

        report = SimulesCLI.render_stats_report(stats)
        @test occursin("Simuleos Project Stats", report)
        @test occursin("sessions: 2", report)
        @test occursin("variables: 3", report)
        @test occursin(string(sid_2), report)

        out = IOBuffer()
        err = IOBuffer()
        exit_code = SimulesCLI.main(["stats", root]; io=out, err_io=err)
        @test exit_code == 0
        @test occursin("Stored Data", String(take!(out)))
        @test isempty(String(take!(err)))

        out = IOBuffer()
        err = IOBuffer()
        exit_code = SimulesCLI.main(["stats", "--unknown"]; io=out, err_io=err)
        @test exit_code == 2
        @test occursin("Unknown option", String(take!(err)))
    end
end
