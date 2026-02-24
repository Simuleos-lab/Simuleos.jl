using Simuleos
using Test
using UUIDs

# Convenience aliases for Kernel ScopeTapes + TapeIO + BlobStorage APIs
const TapeIO = Simuleos.Kernel.TapeIO
const ScopeCommit = Simuleos.Kernel.ScopeCommit
const SimuleosScope = Simuleos.Kernel.SimuleosScope
const InlineScopeVariable = Simuleos.Kernel.InlineScopeVariable
const BlobScopeVariable = Simuleos.Kernel.BlobScopeVariable
const VoidScopeVariable = Simuleos.Kernel.VoidScopeVariable
const HashedScopeVariable = Simuleos.Kernel.HashedScopeVariable
const iterate_tape = Simuleos.Kernel.iterate_tape
const each_tape_records_filtered = Simuleos.Kernel.each_tape_records_filtered
const findfirst_tape_record = Simuleos.Kernel.findfirst_tape_record
const any_tape_record = Simuleos.Kernel.any_tape_record
const findlast_tape_record = Simuleos.Kernel.findlast_tape_record
const tape_stop! = Simuleos.Kernel.stop!
const BlobStorage = Simuleos.Kernel.BlobStorage
const blob_ref = Simuleos.Kernel.blob_ref
const blob_write = Simuleos.Kernel.blob_write
const blob_read = Simuleos.Kernel.blob_read
const blob_metadata = Simuleos.Kernel.blob_metadata
const blob_metadata_indexed = Simuleos.Kernel.blob_metadata_indexed
const exists = Simuleos.Kernel.exists

@testset "TapeIO + ScopeTapes + BlobStorage Query System" begin
    mktempdir() do tmpdir
        simuleos_dir = joinpath(tmpdir, ".simuleos")
        mkpath(simuleos_dir)
        project = Simuleos.Kernel.SimuleosProject(
            id = "query-test-project",
            root_path = tmpdir,
            simuleos_dir = simuleos_dir
        )
        blob_storage = BlobStorage(project)

        test_session_id = uuid4()
        tape_path = Simuleos.Kernel.tape_path(simuleos_dir, test_session_id)
        mkpath(dirname(tape_path))
        tape = TapeIO(tape_path)

        # Write test blob through BlobStorage subsystem
        blob_key = ("test-blob", 1)
        test_data = Dict("foo" => 42, "bar" => [1, 2, 3])
        blob_ref_obj = blob_write(blob_storage, blob_key, test_data)
        blob_hash = blob_ref_obj.hash

        @testset "BlobStorage" begin
            @test blob_ref(blob_key) isa Simuleos.Kernel.BlobRef
            @test blob_ref(blob_key).hash == blob_hash
            @test exists(blob_storage, blob_ref_obj)
            @test exists(blob_storage, blob_key)
            @test blob_read(blob_storage, blob_ref_obj) == test_data
            @test blob_read(blob_storage, blob_key) == test_data

            shard_path = Simuleos.Kernel.blob_tape_shard_path(blob_storage, blob_ref_obj)
            @test isfile(shard_path)
            shard_rows_1 = collect(TapeIO(shard_path))
            @test shard_rows_1[1]["type"] == "tape_metadata"
            @test shard_rows_1[1]["tape_name"] == blob_hash[1:2]
            blob_records_1 = filter(row -> get(row, "type", "") == "blob_record", shard_rows_1)
            @test length(blob_records_1) == 1
            blob_row_1 = blob_records_1[1]
            @test blob_row_1["schema"] == "blob_record_v1"
            @test blob_row_1["blob_hash"] == blob_hash
            @test blob_row_1["hash_prefix"] == blob_hash[1:2]
            @test blob_row_1["blob_relpath"] == blob_hash * Simuleos.Kernel.BLOB_EXT
            @test blob_row_1["serializer"] == "julia/Serialization"
            @test blob_row_1["format"] == "jls"
            @test blob_row_1["payload_hash_alg"] == "sha1"
            @test blob_row_1["payload_hash"] isa String
            @test length(blob_row_1["payload_hash"]) == 40
            @test Int(blob_row_1["byte_size"]) > 0
            @test blob_row_1["replaced_existing"] == false

            @test_throws Simuleos.Kernel.BlobAlreadyExistsError blob_write(blob_storage, blob_key, Dict("foo" => 99))
            overwritten = Dict("foo" => 99)
            force_ref = blob_write(blob_storage, blob_key, overwritten; overwrite=true)
            @test force_ref.hash == blob_hash
            @test blob_read(blob_storage, force_ref) == overwritten

            shard_rows_2 = collect(TapeIO(shard_path))
            blob_records_2 = filter(row -> get(row, "type", "") == "blob_record", shard_rows_2)
            @test length(blob_records_2) == 2
            @test blob_records_2[end]["blob_hash"] == blob_hash
            @test blob_records_2[end]["replaced_existing"] == true

            latest_meta = blob_metadata(blob_storage, blob_ref_obj)
            @test !isnothing(latest_meta)
            @test latest_meta["blob_hash"] == blob_hash
            @test latest_meta["replaced_existing"] == true

            latest_meta_by_hash = blob_metadata(blob_storage, blob_hash)
            @test !isnothing(latest_meta_by_hash)
            @test latest_meta_by_hash["blob_hash"] == blob_hash
            @test latest_meta_by_hash["replaced_existing"] == true

            @test isnothing(blob_metadata(blob_storage, "ffffffffffffffffffffffffffffffffffffffff"))

            @test blob_metadata_indexed(blob_storage, blob_ref_obj)
            @test blob_metadata_indexed(blob_storage, blob_hash)
            @test blob_metadata_indexed(blob_storage, blob_key)
            @test !blob_metadata_indexed(blob_storage, "ffffffffffffffffffffffffffffffffffffffff")

            rm(shard_path; force = true)
            @test !isfile(shard_path)
            @test exists(blob_storage, blob_ref_obj)
            @test !blob_metadata_indexed(blob_storage, blob_ref_obj)

            repair_1 = Simuleos.Kernel.blob_tapes_backfill!(blob_storage)
            @test repair_1.scanned_blobs == 1
            @test repair_1.appended_records == 1
            @test repair_1.skipped_existing == 0
            @test repair_1.shards_loaded == 1
            @test repair_1.shards_written == 1
            @test isfile(shard_path)

            repaired_rows = collect(TapeIO(shard_path))
            repaired_records = filter(row -> get(row, "type", "") == "blob_record", repaired_rows)
            @test length(repaired_records) == 1
            @test repaired_records[1]["blob_hash"] == blob_hash
            @test repaired_records[1]["replaced_existing"] == false
            @test blob_metadata_indexed(blob_storage, blob_ref_obj)

            repair_2 = Simuleos.Kernel.blob_tapes_backfill!(blob_storage)
            @test repair_2.scanned_blobs == 1
            @test repair_2.appended_records == 0
            @test repair_2.skipped_existing == 1
        end

        # Append two commit records (JSONL = one JSON object per line)
        Simuleos.Kernel.append!(tape, Dict(
            "type" => "commit",
            "metadata" => Dict("git_branch" => "main", "timestamp" => "2024-01-15T10:30:00"),
            "scopes" => Any[
                Dict(
                    "variables" => Dict(
                        "x" => Dict("src_type" => "Int64", "src" => "local", "value" => 42),
                        "y" => Dict("src_type" => "Vector{Float64}", "src" => "local", "blob_ref" => blob_hash)
                    ),
                    "labels" => Any["scope1", "iteration", "step1"],
                    "metadata" => Dict("step" => 1)
                )
            ],
            "commit_label" => "first_commit"
        ))

        Simuleos.Kernel.append!(tape, Dict(
            "type" => "commit",
            "metadata" => Dict("git_branch" => "main", "timestamp" => "2024-01-15T10:31:00"),
            "scopes" => Any[
                Dict(
                    "labels" => Any["scope2"],
                    "variables" => Dict(
                        "z" => Dict("src_type" => "String", "src" => "global", "value" => "hello"),
                        "k" => Dict("src_type" => "Tuple{Int64, Int64}", "src" => "local")
                    )
                )
            ]
        ))

        @testset "TapeIO Raw Iteration" begin
            rows = collect(tape)
            @test length(rows) == 3
            @test rows[1]["type"] == "tape_metadata"
            @test rows[1]["tape_name"] == "main"

            commits = filter(row -> get(row, "type", "") == "commit", rows)
            @test length(commits) == 2
            @test commits[1]["commit_label"] == "first_commit"
            @test commits[1]["metadata"]["git_branch"] == "main"
            @test !haskey(commits[2], "commit_label") || isempty(commits[2]["commit_label"])
        end

        @testset "TapeIO Filtered Iteration" begin
            rows = collect(each_tape_records_filtered(
                tape;
                line_filter = (line, ctx) -> occursin("\"first_commit\"", line),
                json_filter = (row, ctx) -> get(row, "type", "") == "commit" &&
                    get(row, "commit_label", "") == "first_commit",
            ))
            @test length(rows) == 1
            @test rows[1]["commit_label"] == "first_commit"

            seen_ctx = Tuple{String, Int}[]
            stopped_rows = collect(each_tape_records_filtered(
                tape;
                line_filter = (line, ctx) -> occursin("\"type\":\"commit\"", line),
                json_filter = (row, ctx) -> begin
                    push!(seen_ctx, (ctx.file, ctx.line_no))
                    tape_stop!(ctx)
                    return get(row, "type", "") == "commit"
                end,
            ))
            @test length(stopped_rows) == 1
            @test length(seen_ctx) == 1
            @test seen_ctx[1][2] == 2
            @test stopped_rows[1]["commit_label"] == "first_commit"

            malformed_skip_path = joinpath(simuleos_dir, "filtered-malformed-skip.jsonl")
            open(malformed_skip_path, "w") do io
                println(io, "{broken")
                println(io, "{\"type\":\"commit\",\"commit_label\":\"hit\",\"metadata\":{},\"scopes\":[]}")
            end
            malformed_skip_tape = TapeIO(malformed_skip_path)
            skipped_rows = collect(each_tape_records_filtered(
                malformed_skip_tape;
                line_filter = (line, ctx) -> occursin("\"hit\"", line),
                json_filter = (row, ctx) -> get(row, "commit_label", "") == "hit",
            ))
            @test length(skipped_rows) == 1
            @test skipped_rows[1]["commit_label"] == "hit"

            json_calls = Ref(0)
            first_row = findfirst_tape_record(
                tape;
                line_filter = (line, ctx) -> occursin("\"type\":\"commit\"", line),
                json_filter = (row, ctx) -> begin
                    json_calls[] += 1
                    return true
                end,
            )
            @test !isnothing(first_row)
            @test first_row["commit_label"] == "first_commit"
            @test json_calls[] == 1

            @test any_tape_record(
                tape;
                line_filter = (line, ctx) -> occursin("\"first_commit\"", line),
                json_filter = (row, ctx) -> get(row, "commit_label", "") == "first_commit",
            )
            @test !any_tape_record(
                tape;
                line_filter = (line, ctx) -> occursin("\"missing-label\"", line),
                json_filter = (row, ctx) -> true,
            )

            last_commit = findlast_tape_record(
                tape;
                line_filter = (line, ctx) -> occursin("\"type\":\"commit\"", line),
                json_filter = (row, ctx) -> get(row, "type", "") == "commit",
            )
            @test !isnothing(last_commit)
            @test get(last_commit, "commit_label", "") == ""
        end

        @testset "HashedScopeVariable tape round-trip" begin
            hashed_tape_path = joinpath(simuleos_dir, "hashed-tape.jsonl")
            hashed_tape = TapeIO(hashed_tape_path)
            test_hash = "abcdef1234567890abcdef1234567890abcdef12"
            Simuleos.Kernel.append!(hashed_tape, Dict(
                "type" => "commit",
                "metadata" => Dict("timestamp" => "2026-02-22T12:00:00"),
                "scopes" => Any[
                    Dict(
                        "labels" => Any["hashed-test"],
                        "variables" => Dict(
                            "h" => Dict("src_type" => "Vector{Int64}", "src" => "local", "value_hash" => test_hash)
                        )
                    )
                ],
                "commit_label" => "hashed_commit"
            ))

            commits = collect(iterate_tape(hashed_tape))
            @test length(commits) == 1
            s = commits[1].scopes[1]
            var_h = s.variables[:h]
            @test var_h isa HashedScopeVariable
            @test var_h.type_short == "Vector{Int64}"
            @test var_h.level == :local
            @test var_h.value_hash == test_hash
        end

        @testset "ScopeTapes Typed Objects" begin
            commits = collect(iterate_tape(tape))
            @test length(commits) == 2

            c1 = commits[1]
            @test c1 isa ScopeCommit
            @test c1.commit_label == "first_commit"
            @test c1.metadata["git_branch"] == "main"
            @test c1.metadata["timestamp"] == "2024-01-15T10:30:00"

            c2 = commits[2]
            @test c2.commit_label == ""
            @test c2.metadata["timestamp"] == "2024-01-15T10:31:00"

            @test length(c1.scopes) == 1
            s = c1.scopes[1]
            @test s isa SimuleosScope
            @test s.labels == ["scope1", "iteration", "step1"]
            @test s.metadata[:step] == 1

            @test length(s.variables) == 2
            var_x = s.variables[:x]
            var_y = s.variables[:y]
            @test var_x isa InlineScopeVariable
            @test var_x.type_short == "Int64"
            @test var_x.level == :local
            @test var_x.value == 42
            @test var_y isa BlobScopeVariable
            @test var_y.type_short == "Vector{Float64}"
            @test var_y.level == :local
            @test var_y.blob_ref.hash == blob_hash

            s2 = c2.scopes[1]
            @test s2.variables[:k] isa VoidScopeVariable
        end

        @testset "TapeIO Key Normalization" begin
            normalized_tape = TapeIO(joinpath(simuleos_dir, "normalized.tape.jsonl"))
            Simuleos.Kernel.append!(normalized_tape, Dict{Symbol, Any}(
                :type => "commit",
                :metadata => Dict(:alpha => 1),
                :scopes => Any[]
            ))
            rows = collect(normalized_tape)
            @test length(rows) == 2
            @test rows[1]["type"] == "tape_metadata"
            @test rows[2]["metadata"]["alpha"] == 1
        end

        @testset "TapeIO Fragmented Directory Mode" begin
            frag_dir = joinpath(simuleos_dir, "sessions", string(uuid4()), "tapes", "main")
            fragmented_tape = TapeIO(frag_dir)

            Simuleos.Kernel.append!(fragmented_tape, Dict(
                "type" => "commit",
                "commit_label" => "f1",
                "metadata" => Dict("timestamp" => "2026-02-18T12:00:02"),
                "scopes" => Any[]
            ))
            @test isfile(joinpath(frag_dir, "frag1.jsonl"))

            # Add a second fragment explicitly and ensure directory iteration reads both.
            frag2_path = joinpath(frag_dir, "frag2.jsonl")
            open(frag2_path, "w") do io
                println(io, Simuleos.Kernel._to_json_string(Dict(
                    "type" => "commit",
                    "commit_label" => "f2",
                    "metadata" => Dict("timestamp" => "2026-02-18T12:00:03"),
                    "scopes" => Any[]
                )))
            end

            rows = collect(fragmented_tape)
            @test length(rows) == 3
            @test rows[1]["type"] == "tape_metadata"
            commits = filter(row -> get(row, "type", "") == "commit", rows)
            @test length(commits) == 2
            @test commits[1]["commit_label"] == "f1"
            @test commits[2]["commit_label"] == "f2"
        end

        @testset "TapeIO Single-File Metadata Record" begin
            path = joinpath(simuleos_dir, "single-file-tape.jsonl")
            file_tape = TapeIO(path)
            Simuleos.Kernel.append!(file_tape, Dict(
                "type" => "commit",
                "commit_label" => "c1",
                "metadata" => Dict("timestamp" => "2026-02-18T12:00:04"),
                "scopes" => Any[]
            ))

            rows = collect(file_tape)
            @test length(rows) == 2
            @test rows[1]["type"] == "tape_metadata"
            @test rows[1]["tape_name"] == "single-file-tape"
            @test rows[2]["type"] == "commit"
        end

        @testset "TapeIO Empty/Malformed Cases" begin
            missing_tape = TapeIO(joinpath(simuleos_dir, "missing.tape.jsonl"))
            @test isempty(collect(missing_tape))

            malformed_tape = TapeIO(joinpath(simuleos_dir, "malformed.tape.jsonl"))
            open(malformed_tape.path, "w") do io
                println(io, "{\"ok\":1}")
                println(io, "{broken")
            end
            @test_throws ErrorException collect(malformed_tape)
        end
    end
end

@testset "BlobStorage SimOs wrappers" begin
    mktempdir() do project_root
        simuleos_dir = joinpath(project_root, ".simuleos")
        mkpath(simuleos_dir)
        project = Simuleos.Kernel.SimuleosProject(
            id = "test-project",
            root_path = project_root,
            simuleos_dir = simuleos_dir
        )
        storage = BlobStorage(project)
        project.blobstorage = storage
        sim = Simuleos.Kernel.SimOs(project = project)

        key = ("simos", :blob)
        value = Dict(:a => 1, :b => [2, 3])
        ref = blob_write(sim, key, value)

        @test ref isa Simuleos.Kernel.BlobRef
        @test blob_read(sim, key) == value
        @test blob_read(sim, ref) == value
    end
end
