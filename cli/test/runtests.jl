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

@testset "Simules CLI system.init" begin
    mktempdir() do root
        # First call: creates the project
        out = IOBuffer()
        err = IOBuffer()
        exit_code = SimulesCLI.main(["system.init", root]; io=out, err_io=err)
        @test exit_code == 0
        out_str = String(take!(out))
        @test occursin("System initialized.", out_str)
        @test occursin("status:       created", out_str)
        @test isempty(String(take!(err)))

        # Second call: loads the existing project
        out = IOBuffer()
        err = IOBuffer()
        exit_code = SimulesCLI.main(["system.init", root]; io=out, err_io=err)
        @test exit_code == 0
        out_str = String(take!(out))
        @test occursin("status:       loaded", out_str)
        @test isempty(String(take!(err)))
    end
end

@testset "Simules CLI project.current" begin
    mktempdir() do root
        # No project yet — should fail
        out = IOBuffer()
        err = IOBuffer()
        exit_code = SimulesCLI.main(["project.current", root]; io=out, err_io=err)
        @test exit_code == 1
        @test occursin("No .simuleos project", String(take!(err)))

        # Init project, then find it
        Simuleos.Kernel.proj_init_at(root)
        out = IOBuffer()
        err = IOBuffer()
        exit_code = SimulesCLI.main(["project.current", root]; io=out, err_io=err)
        @test exit_code == 0
        out_str = String(take!(out))
        @test occursin("Project", out_str)
        @test occursin("root:", out_str)
        @test occursin("simuleos_dir:", out_str)
        @test occursin("id:", out_str)
        @test isempty(String(take!(err)))
    end
end

@testset "Simules CLI blob.meta" begin
    mktempdir() do root
        project_driver = Simuleos.Kernel.proj_init_at(root)

        # Write a blob and get its hash
        ref = Simuleos.Kernel.blob_write(project_driver.blobstorage, :test_key, [1, 2, 3])
        hash = ref.hash

        # Found
        out = IOBuffer()
        err = IOBuffer()
        exit_code = SimulesCLI.main(["blob.meta", hash, "--project=$(root)"]; io=out, err_io=err)
        @test exit_code == 0
        out_str = String(take!(out))
        @test occursin("blob_hash", out_str)
        @test occursin(hash, out_str)
        @test isempty(String(take!(err)))

        # Not found
        missing_hash = "a" ^ 40
        out = IOBuffer()
        err = IOBuffer()
        exit_code = SimulesCLI.main(["blob.meta", missing_hash, "--project=$(root)"]; io=out, err_io=err)
        @test exit_code == 1
        @test occursin("(not found)", String(take!(out)))
        @test isempty(String(take!(err)))
    end
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
