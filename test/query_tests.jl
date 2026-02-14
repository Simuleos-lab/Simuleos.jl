using Simuleos
using Test
using Dates

# Convenience aliases for Kernel ScopeTapes + TapeIO + BlobStorage APIs
const TapeIO = Simuleos.Kernel.TapeIO
const CommitRecord = Simuleos.Kernel.CommitRecord
const ScopeRecord = Simuleos.Kernel.ScopeRecord
const VariableRecord = Simuleos.Kernel.VariableRecord
const iterate_tape = Simuleos.Kernel.iterate_tape
const BlobStorage = Simuleos.Kernel.BlobStorage
const blob_ref = Simuleos.Kernel.blob_ref
const blob_write = Simuleos.Kernel.blob_write
const blob_read = Simuleos.Kernel.blob_read
const exists = Simuleos.Kernel.exists

@testset "TapeIO + ScopeTapes + BlobStorage Query System" begin
    mktempdir() do tmpdir
        simuleos_dir = joinpath(tmpdir, ".simuleos")
        mkpath(simuleos_dir)
        blob_storage = BlobStorage(simuleos_dir)

        tape_path = Simuleos.Kernel.tape_path(simuleos_dir)
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

            @test_throws Exception blob_write(blob_storage, blob_key, Dict("foo" => 99))
            overwritten = Dict("foo" => 99)
            force_ref = blob_write(blob_storage, blob_key, overwritten; overwrite=true)
            @test force_ref.hash == blob_hash
            @test blob_read(blob_storage, force_ref) == overwritten
        end

        # Append two commit records (JSONL = one JSON object per line)
        Simuleos.Kernel.append!(tape, Dict(
            "type" => "commit",
            "metadata" => Dict("git_branch" => "main"),
            "scopes" => Any[
                Dict(
                    "label" => "scope1",
                    "timestamp" => "2024-01-15T10:30:00",
                    "variables" => Dict(
                        "x" => Dict("src_type" => "Int64", "src" => "local", "value" => 42),
                        "y" => Dict("src_type" => "Vector{Float64}", "src" => "local", "blob_ref" => blob_hash)
                    ),
                    "labels" => Any["iteration", "step1"],
                    "data" => Dict("step" => 1)
                )
            ],
            "blob_refs" => Any[blob_hash],
            "commit_label" => "first_commit"
        ))

        Simuleos.Kernel.append!(tape, Dict(
            "type" => "commit",
            "metadata" => Dict("git_branch" => "main"),
            "scopes" => Any[
                Dict(
                    "label" => "scope2",
                    "timestamp" => "2024-01-15T10:31:00",
                    "variables" => Dict(
                        "z" => Dict("src_type" => "String", "src" => "global", "value" => "hello")
                    )
                )
            ],
            "blob_refs" => Any[]
        ))

        @testset "TapeIO Raw Iteration" begin
            commits = collect(tape)
            @test length(commits) == 2
            @test commits[1]["commit_label"] == "first_commit"
            @test commits[1]["metadata"]["git_branch"] == "main"
            @test !haskey(commits[2], "commit_label") || isempty(commits[2]["commit_label"])
        end

        @testset "ScopeTapes Typed Records" begin
            commits = collect(iterate_tape(tape))
            @test length(commits) == 2

            c1 = commits[1]
            @test c1 isa CommitRecord
            @test c1.commit_label == "first_commit"
            @test c1.metadata["git_branch"] == "main"
            @test c1.blob_refs == [blob_hash]

            c2 = commits[2]
            @test c2.commit_label == ""
            @test isempty(c2.blob_refs)

            @test length(c1.scopes) == 1
            s = c1.scopes[1]
            @test s isa ScopeRecord
            @test s.label == "scope1"
            @test s.timestamp == DateTime(2024, 1, 15, 10, 30, 0)
            @test s.labels == ["iteration", "step1"]
            @test s.data["step"] == 1

            @test length(s.variables) == 2
            var_x = only(filter(v -> v.name == "x", s.variables))
            var_y = only(filter(v -> v.name == "y", s.variables))
            @test var_x isa VariableRecord
            @test var_x.src_type == "Int64"
            @test var_x.src == :local
            @test var_x.value == 42
            @test isnothing(var_x.blob_ref)
            @test var_y.src_type == "Vector{Float64}"
            @test var_y.src == :local
            @test isnothing(var_y.value)
            @test var_y.blob_ref == blob_hash
        end

        @testset "TapeIO Key Normalization" begin
            normalized_tape = TapeIO(joinpath(simuleos_dir, "normalized.tape.jsonl"))
            Simuleos.Kernel.append!(normalized_tape, Dict{Symbol, Any}(
                :type => "commit",
                :metadata => Dict(:alpha => 1),
                :scopes => Any[],
                :blob_refs => Any[]
            ))
            rows = collect(normalized_tape)
            @test length(rows) == 1
            @test rows[1]["metadata"]["alpha"] == 1
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
        storage = BlobStorage(simuleos_dir)
        project = Simuleos.Kernel.Project(
            id = "test-project",
            root_path = project_root,
            simuleos_dir = simuleos_dir,
            blobstorage = storage
        )
        sim = Simuleos.Kernel.SimOs(project_root = project_root, project = project)

        key = ("simos", :blob)
        value = Dict(:a => 1, :b => [2, 3])
        ref = blob_write(sim, key, value)

        @test ref isa Simuleos.Kernel.BlobRef
        @test blob_read(sim, key) == value
        @test blob_read(sim, ref) == value
    end
end
