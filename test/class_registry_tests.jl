using Simuleos
using Test

const K = Simuleos.Kernel

@testset "Kernel semantic class registry" begin
    @testset "builtin catalog bootstrap" begin
        expected_specs = [
            "src.codebase@v1",
            "src.runtime_host@v1",
            "src.execution_site@v1",
            "src.namespace_bindings@v1",
            "src.settings_access@v1",
            "src.session_state@v1",
            "snap.scope@v1",
            "snap.context@v1",
            "snap.shared@v1",
            "rec.capture_commit@v1",
            "rec.ref@v1",
        ]
        for spec in expected_specs
            @test K.class_exists(spec)
        end
    end

    K._class_registry_reset!()
    try
        @testset "parse and Julia class tags" begin
            parsed = K.class_parse("snap.scope@v1")
            @test parsed.id == "snap.scope"
            @test parsed.version == 1
            @test parsed.spec == "snap.scope@v1"

            tag = K.class_tag("snap.scope@v1")
            @test K.class_id(tag) == "snap.scope"
            @test K.class_version(tag) == 1
            @test K.class_spec_string(tag) == "snap.scope@v1"

            tag2 = K.class_tag("snap.scope", 2)
            @test K.class_id(tag2) == "snap.scope"
            @test K.class_version(tag2) == 2

            @test_throws ErrorException K.class_parse("snap.scope")
            @test_throws ErrorException K.class_parse("Snap.scope@v1")
            @test_throws ErrorException K.class_parse("snap.scope@v0")
            @test_throws ErrorException K.class_parse("snap.scope@vx")
            @test_throws ErrorException K.class_tag("snap..scope@v1")
        end

        @testset "metadata registration and invariants" begin
            ns = K.class_register!("src.namespace_bindings", 1)
            ex = K.class_register!("src.execution_site", 1)

            @test K.class_exists("src.namespace_bindings")
            @test K.class_exists("src.namespace_bindings@v1")
            @test K.class_exists("src.execution_site", 1)
            @test !K.class_exists("src.execution_site", 2)
            @test K.class_spec("src.execution_site@v1") === ex
            @test K.class_spec("src.namespace_bindings") === ns

            scope_v1 = K.class_register!(
                K.SimuleosClassSpec("snap.scope", 1;
                    compose_from = ["src.namespace_bindings@v1", "src.execution_site@v1"],
                    fields = [
                        K.SimuleosClassFieldSpec("labels", "vector[string]"),
                        (name = "variables", semantic_type = "map[symbol,binding]", required = true),
                        (name = "metadata", semantic_type = "map[symbol,any]", required = false),
                    ],
                ),
            )
            @test K.class_exists("snap.scope@v1")
            @test K.class_spec("snap.scope@v1") === scope_v1
            @test length(scope_v1.fields) == 3

            @test_throws ErrorException K.class_register!("snap.scope", 1)
            @test_throws ErrorException K.class_register!("src.bad", 0)
            @test_throws ErrorException K.class_register!("src.bad-id!", 1)
            @test_throws ErrorException K.class_register!(
                "snap.context", 1;
                compose_from = ["src.settings_access@v1"],
            )

            scope_v2 = K.class_register!(
                "snap.scope",
                2;
                compose_from = ["src.namespace_bindings@v1", "src.execution_site@v1"],
            )
            @test K.class_spec("snap.scope@v2") === scope_v2
            @test_throws ErrorException K.class_spec("snap.scope")
        end

        @testset "metadata-only registry and dispatch separation" begin
            @test !any(t -> t <: Function, fieldtypes(K.SimuleosClassSpec))

            decode_demo(::K.SimuleosClass{Symbol("snap.scope"), 1}, raw) = ("scope", raw)
            decode_demo(::K.SimuleosClass, raw) = ("generic", raw)

            tag = K.class_tag("snap.scope@v1")
            @test decode_demo(tag, Dict("x" => 1))[1] == "scope"
            @test decode_demo(K.class_tag("snap.scope@v2"), Dict("x" => 1))[1] == "generic"
        end

        @testset "scope write boundary class gate" begin
            K._class_registry_reset!()
            mktempdir() do tmp
                tape = K.TapeIO(joinpath(tmp, "scope-class-gate.jsonl"))
                scope = K.ScopeSnapshot(
                    ["scope-gate"],
                    Dict{Symbol, K.ScopeVariable}(:x => K.InlineScopeVariable(:local, "Int64", 1)),
                    Dict{Symbol, Any}(),
                )
                commit = K.CaptureTree(
                    "gate-commit",
                    K.PartialSnapshot[scope],
                    K.CaptureTree[],
                    Dict{String, Any}(),
                )

                @test_throws ErrorException K.append!(tape, commit)

                K.classsystem_bootstrap!()
                @test K.append!(tape, commit) === tape

                rows = collect(tape)
                commit_row = rows[end]
                @test commit_row["type"] == "commit"
                @test commit_row["scopes"][1]["class_id"] == "snap.scope"
                @test commit_row["scopes"][1]["class_version"] == 1
            end
        end

        @testset "scope read dispatch by class tag" begin
            K.classsystem_bootstrap!()

            mktempdir() do tmp
                tape = K.TapeIO(joinpath(tmp, "scope-class-read.jsonl"))
                K.append!(tape, Dict(
                    "type" => "commit",
                    "metadata" => Dict("timestamp" => "2026-02-28T12:00:00"),
                    "scopes" => Any[
                        Dict(
                            "class_id" => "snap.scope",
                            "class_version" => 1,
                            "labels" => Any["read-dispatch"],
                            "variables" => Dict(
                                "x" => Dict("src_type" => "Int64", "src" => "local", "value" => 7),
                            ),
                            "metadata" => Dict("step" => 1),
                        ),
                    ],
                    "commit_label" => "class-read",
                ))

                scopes = K.fetch_scope_snapshots(tape)
                @test length(scopes) == 1
                @test scopes[1].labels == ["read-dispatch"]
                @test scopes[1].metadata[:step] == 1
                @test scopes[1].variables[:x] isa K.InlineScopeVariable
            end

            mktempdir() do tmp
                tape = K.TapeIO(joinpath(tmp, "scope-class-read-invalid.jsonl"))
                K.append!(tape, Dict(
                    "type" => "commit",
                    "metadata" => Dict{String, Any}(),
                    "scopes" => Any[
                        Dict(
                            "class_id" => "snap.unknown",
                            "class_version" => 1,
                            "labels" => Any["bad-class"],
                            "variables" => Dict{String, Any}(),
                        ),
                    ],
                    "commit_label" => "bad-class-read",
                ))

                @test_throws ErrorException K.fetch_scope_snapshots(tape)
            end
        end
    finally
        K._class_registry_reset!()
        K.classsystem_bootstrap!()
    end
end
