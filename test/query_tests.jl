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

            @test_throws Exception blob_write(blob_storage, blob_key, Dict("foo" => 99))
            overwritten = Dict("foo" => 99)
            force_ref = blob_write(blob_storage, blob_key, overwritten; overwrite=true)
            @test force_ref.hash == blob_hash
            @test blob_read(blob_storage, force_ref) == overwritten
        end

        # Append two commit records (JSONL = one JSON object per line)
        Simuleos.Kernel.append!(tape, Dict(
            "type" => "commit",
            "metadata" => Dict("git_branch" => "main", "timestamp" => "2024-01-15T10:30:00"),
            "scopes" => Any[
                Dict(
                    "label" => "scope1",
                    "variables" => Dict(
                        "x" => Dict("src_type" => "Int64", "src" => "local", "value" => 42),
                        "y" => Dict("src_type" => "Vector{Float64}", "src" => "local", "blob_ref" => blob_hash)
                    ),
                    "labels" => Any["iteration", "step1"],
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
                    "label" => "scope2",
                    "variables" => Dict(
                        "z" => Dict("src_type" => "String", "src" => "global", "value" => "hello"),
                        "k" => Dict("src_type" => "Tuple{Int64, Int64}", "src" => "local")
                    )
                )
            ]
        ))

        @testset "TapeIO Raw Iteration" begin
            commits = collect(tape)
            @test length(commits) == 2
            @test commits[1]["commit_label"] == "first_commit"
            @test commits[1]["metadata"]["git_branch"] == "main"
            @test !haskey(commits[2], "commit_label") || isempty(commits[2]["commit_label"])
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
        project = Simuleos.Kernel.SimuleosProject(
            id = "test-project",
            root_path = project_root,
            simuleos_dir = simuleos_dir,
            blobstorage = storage
        )
        sim = Simuleos.Kernel.SimOs(project = project)

        key = ("simos", :blob)
        value = Dict(:a => 1, :b => [2, 3])
        ref = blob_write(sim, key, value)

        @test ref isa Simuleos.Kernel.BlobRef
        @test blob_read(sim, key) == value
        @test blob_read(sim, ref) == value
    end
end
