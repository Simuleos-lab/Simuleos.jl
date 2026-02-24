using Simuleos
using Test
using UUIDs

global _simuleos_expand_global = 0

@testset "ScopeReader project-driven interface" begin
    mktempdir() do root
        simuleos_dir = joinpath(root, ".simuleos")
        mkpath(simuleos_dir)

        open(joinpath(simuleos_dir, "project.json"), "w") do io
            Simuleos.Kernel.JSON3.pretty(io, Dict("id" => "reader-project"))
        end

        project_driver = Simuleos.project(root)
        storage = Simuleos.Kernel.BlobStorage(project_driver)

        session_id = uuid4()
        session_dir = joinpath(simuleos_dir, "sessions", string(session_id))
        mkpath(joinpath(session_dir, "tapes", "main"))
        open(joinpath(session_dir, "session.json"), "w") do io
            Simuleos.Kernel.JSON3.pretty(io, Dict(
                "session_id" => string(session_id),
                "labels" => Any["reader-test", "smoke"],
                "meta" => Dict("timestamp" => "2026-02-18T12:00:00"),
            ))
        end

        blob_ref = Simuleos.Kernel.blob_write(storage, ("blob-key", 1), Dict("a" => 1))
        tape = Simuleos.Kernel.TapeIO(Simuleos.Kernel.tape_path(simuleos_dir, session_id))
        Simuleos.Kernel.append!(tape, Dict(
            "type" => "commit",
            "commit_label" => "c1",
            "metadata" => Dict("timestamp" => "2026-02-18T12:00:01"),
            "scopes" => Any[
                Dict(
                    "variables" => Dict(
                        "x" => Dict("src_type" => "Int64", "src" => "local", "value" => 42),
                        "b" => Dict("src_type" => "Dict", "src" => "local", "blob_ref" => blob_ref.hash),
                        "v" => Dict("src_type" => "Vector", "src" => "local"),
                        "_simuleos_expand_global" => Dict("src_type" => "Int64", "src" => "global", "value" => 7),
                    ),
                    "labels" => Any["scope-one", "tag"]
                )
            ]
        ))

        scopes_by_label = collect(Simuleos.each_scopes(project_driver; session="reader-test"))
        @test length(scopes_by_label) == 1
        @test scopes_by_label[1].labels == ["scope-one", "tag"]
        latest = Simuleos.latest_scope(project_driver; session="reader-test")
        @test latest.labels == ["scope-one", "tag"]

        @test Simuleos.value(scopes_by_label[1].variables[:x], project_driver) == 42
        @test Simuleos.value(scopes_by_label[1].variables[:v], project_driver) === nothing
        @test Simuleos.value(scopes_by_label[1].variables[:b], project_driver) == Dict("a" => 1)

        @testset "@simos scope.bind macro" begin
            scope = scopes_by_label[1]

            let x = -1
                @simos scope.bind(scope, project_driver, x)
                @test x == 42
            end

            let _simuleos_expand_global = -1
                @simos scope.bind(scope, project_driver, _simuleos_expand_global)
                @test _simuleos_expand_global == -1
            end
            @test _simuleos_expand_global == 7

            @test_throws ErrorException begin
                @simos scope.bind(scope, project_driver, does_not_exist_in_scope)
            end
        end

        scopes_by_uuid = collect(Simuleos.each_scopes(project_driver; session=session_id))
        @test length(scopes_by_uuid) == 1
        latest_by_uuid = Simuleos.latest_scope(project_driver; session=session_id)
        @test latest_by_uuid.labels == ["scope-one", "tag"]

        @test_throws ErrorException collect(Simuleos.each_scopes(project_driver; session="missing-label"))
        @test_throws ErrorException Simuleos.latest_scope(project_driver; session="missing-label")

        @testset "scope_table" begin
            rows = Simuleos.scope_table(project_driver; session="reader-test")
            @test length(rows) == 1
            row = rows[1]
            @test row[:commit_label] == "c1"
            @test row[:scope_labels] == "scope-one;tag"
            # resolved variable values
            @test row[:x] == 42
            @test row[:b] == Dict("a" => 1)
            @test row[:v] === nothing
            @test row[:_simuleos_expand_global] == 7

            # commit_label filtering
            rows_miss = Simuleos.scope_table(project_driver; session="reader-test", commit_label="no-such")
            @test isempty(rows_miss)

            rows_hit = Simuleos.scope_table(project_driver; session="reader-test", commit_label="c1")
            @test length(rows_hit) == 1
        end

        @testset "latest_scope filtered lookup" begin
            session_id2 = uuid4()
            session_dir2 = joinpath(simuleos_dir, "sessions", string(session_id2))
            mkpath(joinpath(session_dir2, "tapes", "main"))
            open(joinpath(session_dir2, "session.json"), "w") do io
                Simuleos.Kernel.JSON3.pretty(io, Dict(
                    "session_id" => string(session_id2),
                    "labels" => Any["reader-filter", "smoke"],
                    "meta" => Dict("timestamp" => "2026-02-18T12:00:10"),
                ))
            end

            tape2 = Simuleos.Kernel.TapeIO(Simuleos.Kernel.tape_path(simuleos_dir, session_id2))
            Simuleos.Kernel.append!(tape2, Dict(
                "type" => "commit",
                "commit_label" => "stage-output",
                "metadata" => Dict("timestamp" => "2026-02-18T12:00:11"),
                "scopes" => Any[
                    Dict(
                        "labels" => Any["first"],
                        "metadata" => Dict("src_file" => "/tmp/pipeline/stage.jl", "step" => 1),
                        "variables" => Dict("x" => Dict("src_type" => "Int64", "src" => "local", "value" => 1))
                    )
                ]
            ))
            Simuleos.Kernel.append!(tape2, Dict(
                "type" => "commit",
                "commit_label" => "other-output",
                "metadata" => Dict("timestamp" => "2026-02-18T12:00:12"),
                "scopes" => Any[
                    Dict(
                        "labels" => Any["other"],
                        "metadata" => Dict("src_file" => "/tmp/pipeline/other.jl", "step" => 9),
                        "variables" => Dict("x" => Dict("src_type" => "Int64", "src" => "local", "value" => 9))
                    )
                ]
            ))
            Simuleos.Kernel.append!(tape2, Dict(
                "type" => "commit",
                "commit_label" => "stage-output",
                "metadata" => Dict("timestamp" => "2026-02-18T12:00:13"),
                "scopes" => Any[
                    Dict(
                        "labels" => Any["second"],
                        "metadata" => Dict("src_file" => "/tmp/pipeline/stage.jl", "step" => 2),
                        "variables" => Dict("x" => Dict("src_type" => "Int64", "src" => "local", "value" => 2))
                    )
                ]
            ))

            latest_by_label = Simuleos.latest_scope(
                project_driver; session="reader-filter", commit_label="stage-output")
            @test latest_by_label.metadata[:step] == 2
            @test latest_by_label.labels == ["second"]

            latest_by_src = Simuleos.latest_scope(
                project_driver; session="reader-filter", src_file="stage.jl")
            @test latest_by_src.metadata[:step] == 2
            @test latest_by_src.labels == ["second"]

            latest_both = Simuleos.latest_scope(
                project_driver; session="reader-filter", commit_label="stage-output", src_file="stage.jl")
            @test latest_both.metadata[:step] == 2
            @test latest_both.labels == ["second"]
        end
    end
end
