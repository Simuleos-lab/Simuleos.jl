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

            decode_demo(::K.SimuleosClassTag{Symbol("snap.scope"), 1}, raw) = ("scope", raw)
            decode_demo(::K.SimuleosClassTag, raw) = ("generic", raw)

            tag = K.class_tag("snap.scope@v1")
            @test decode_demo(tag, Dict("x" => 1))[1] == "scope"
            @test decode_demo(K.class_tag("snap.scope@v2"), Dict("x" => 1))[1] == "generic"
        end

        @testset "scope write boundary class gate" begin
            K._class_registry_reset!()
            mktempdir() do tmp
                tape = K.TapeIO(joinpath(tmp, "scope-class-gate.jsonl"))
                scope = K.SnapScopeV1(
                    ["scope-gate"],
                    Dict{Symbol, K.ScopeVariable}(:x => K.InlineScopeVariable(:local, "Int64", 1)),
                    Dict{Symbol, Any}(),
                )
                capture = K.CaptureTree(
                    "gate-commit",
                    K.SimuleosDataClass[scope],
                    K.CaptureTree[],
                    Dict{String, Any}(),
                )
                commit = K.RecCaptureCommitV1(; label="gate-commit", capture=capture)

                @test_throws ErrorException K.append!(tape, commit)

                K.classsystem_bootstrap!()
                @test K.append!(tape, commit) === tape

                rows = collect(tape)
                commit_row = rows[end]
                @test commit_row["class_id"] == "rec.capture_commit"
                @test commit_row["scopes"][1]["class_id"] == "snap.scope"
                @test commit_row["scopes"][1]["class_version"] == 1
            end
        end

        @testset "scope read dispatch by class tag" begin
            K.classsystem_bootstrap!()

            mktempdir() do tmp
                tape = K.TapeIO(joinpath(tmp, "scope-class-read.jsonl"))
                K.append!(tape, Dict(
                    "class_id" => "rec.capture_commit", "class_version" => 1,
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
                    "class_id" => "rec.capture_commit", "class_version" => 1,
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

        @testset "shared scope class dispatch by class tag" begin
            K.classsystem_bootstrap!()

            raw = Dict{String, Any}(
                "class_id" => "snap.shared",
                "class_version" => 1,
                "shared_key" => "typed",
                "labels" => Any["typed"],
                "variables" => Dict(
                    "x" => Dict("src_type" => "Float64", "src" => "shared", "value" => 1.5),
                ),
                "metadata" => Dict("src_file" => "script.jl", "src_line" => 10),
            )

            shared = K.decode_snap_shared_record(raw)
            @test shared isa K.SnapSharedV1
            @test shared.shared_key == "typed"
            @test shared.labels == ["typed"]
            @test shared.variables[:x] isa K.InlineScopeVariable
            @test shared.metadata[:src_line] == 10

            encoded = K.encode_snap_shared_record(shared)
            @test encoded["class_id"] == "snap.shared"
            @test encoded["class_version"] == 1
            @test encoded["shared_key"] == "typed"
            @test encoded["variables"]["x"]["src"] == "shared"
        end

        @testset "builtin class runtime coverage uses typed DataClasses" begin
            K.classsystem_bootstrap!()

            scope_raw = Dict{String, Any}(
                "class_id" => "snap.scope",
                "class_version" => 1,
                "labels" => Any["scope-a"],
                "variables" => Dict(
                    "x" => Dict("src_type" => "Int64", "src" => "local", "value" => 3),
                ),
                "metadata" => Dict("step" => 1),
            )

            settings_raw = Dict{String, Any}(
                "class_id" => "src.settings_access",
                "class_version" => 1,
                "accessed" => Dict("run.alpha" => 0.5),
                "timestamp" => "2026-03-04T12:00:00",
            )

            source_raw = Dict{String, Any}(
                "class_id" => "src.codebase",
                "class_version" => 1,
                "git_commit" => "abc",
                "git_branch" => "main",
                "git_dirty" => false,
                "git_describe" => "v0.1.0",
            )

            env_raw = Dict{String, Any}(
                "class_id" => "src.runtime_host",
                "class_version" => 1,
                "julia_version" => "1.11.0",
                "hostname" => "node",
                "os" => "Linux",
                "word_size" => 64,
                "threads" => 4,
                "timestamp" => "2026-03-04T12:00:00",
            )

            exec_raw = Dict{String, Any}(
                "class_id" => "src.execution_site",
                "class_version" => 1,
                "src_file" => "script.jl",
                "src_line" => 9,
                "threadid" => 1,
                "timestamp" => "2026-03-04T12:00:01",
            )

            namespace_raw = Dict{String, Any}(
                "class_id" => "src.namespace_bindings",
                "class_version" => 1,
                "labels" => Any["scope-a"],
                "variables" => Dict(
                    "x" => Dict("src_type" => "Int64", "src" => "local", "value" => 3),
                ),
                "metadata" => Dict("step" => 1),
            )

            session_state_raw = Dict{String, Any}(
                "class_id" => "src.session_state",
                "class_version" => 1,
                "session_id" => string(Base.UUID("00000000-0000-0000-0000-000000000001")),
                "labels" => Any["label-a"],
                "meta" => Dict("timestamp" => "2026-03-04T12:00:02"),
            )

            context_raw = Dict{String, Any}(
                "class_id" => "snap.context",
                "class_version" => 1,
                "settings" => settings_raw,
                "source" => source_raw,
                "environment" => env_raw,
                "execution" => exec_raw,
                "session_id" => session_state_raw["session_id"],
                "labels" => Any["label-a"],
            )

            shared_raw = Dict{String, Any}(
                "class_id" => "snap.shared",
                "class_version" => 1,
                "shared_key" => "shared-a",
                "labels" => Any["shared-a"],
                "variables" => Dict(
                    "x" => Dict("src_type" => "Int64", "src" => "shared", "value" => 3),
                ),
                "metadata" => Dict("src_line" => 12),
            )

            capture_commit_raw = Dict{String, Any}(
                "class_id" => "rec.capture_commit",
                "class_version" => 1,
                "metadata" => Dict("timestamp" => "2026-03-04T12:00:03"),
                "scopes" => Any[scope_raw],
                "commit_label" => "commit-a",
            )

            rec_ref_raw = Dict{String, Any}(
                "class_id" => "rec.ref",
                "class_version" => 1,
                "record_hash" => "0123456789abcdef0123456789abcdef01234567",
                "record_short" => "0123456789ab",
                "writer" => "Simuleos",
                "timetag" => "2026-03-04T12:00:04",
                "payload" => context_raw,
            )

            coverage = [
                (raw = source_raw, decode = K.decode_src_codebase_record, encode = K.encode_src_codebase_record, T = K.SrcCodebaseV1),
                (raw = env_raw, decode = K.decode_src_runtime_host_record, encode = K.encode_src_runtime_host_record, T = K.SrcRuntimeHostV1),
                (raw = exec_raw, decode = K.decode_src_execution_site_record, encode = K.encode_src_execution_site_record, T = K.SrcExecutionSiteV1),
                (raw = namespace_raw, decode = K.decode_src_namespace_bindings_record, encode = K.encode_src_namespace_bindings_record, T = K.SrcNamespaceBindingsV1),
                (raw = settings_raw, decode = K.decode_src_settings_access_record, encode = K.encode_src_settings_access_record, T = K.SrcSettingsAccessV1),
                (raw = session_state_raw, decode = K.decode_src_session_state_record, encode = K.encode_src_session_state_record, T = K.SrcSessionStateV1),
                (raw = scope_raw, decode = K.decode_snap_scope_record, encode = K.encode_snap_scope_record, T = K.SnapScopeV1),
                (raw = context_raw, decode = K.decode_snap_context_record, encode = K.encode_snap_context_record, T = K.SnapContextV1),
                (raw = shared_raw, decode = K.decode_snap_shared_record, encode = K.encode_snap_shared_record, T = K.SnapSharedV1),
                (raw = capture_commit_raw, decode = K.decode_rec_capture_commit_record, encode = K.encode_rec_capture_commit_record, T = K.RecCaptureCommitV1),
                (raw = rec_ref_raw, decode = K.decode_rec_ref_record, encode = K.encode_rec_ref_record, T = K.RecRefV1),
            ]

            for item in coverage
                decoded = item.decode(item.raw)
                @test decoded isa item.T
                @test decoded isa K.SimuleosDataClass
                @test !(decoded isa AbstractDict)

                encoded = item.encode(decoded)
                @test encoded isa Dict{String, Any}
                @test encoded["class_id"] == item.raw["class_id"]
                @test encoded["class_version"] == item.raw["class_version"]
            end
        end
    finally
        K._class_registry_reset!()
        K.classsystem_bootstrap!()
    end
end
