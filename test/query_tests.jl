using Simuleos
using Test
using Dates

# Convenience aliases for Kernel ScopeTapes + BlobStorage APIs
const RootHandler = Simuleos.Kernel.RootHandler
const SessionHandler = Simuleos.Kernel.SessionHandler
const TapeHandler = Simuleos.Kernel.TapeHandler
const BlobRef = Simuleos.Kernel.BlobRef
const CommitRecord = Simuleos.Kernel.CommitRecord
const ScopeRecord = Simuleos.Kernel.ScopeRecord
const VariableRecord = Simuleos.Kernel.VariableRecord
const sessions = Simuleos.Kernel.sessions
const tape = Simuleos.Kernel.tape
const exists = Simuleos.Kernel.exists
const iterate_raw_tape = Simuleos.Kernel.iterate_raw_tape
const iterate_tape = Simuleos.Kernel.iterate_tape
const blob_ref = Simuleos.Kernel.blob_ref
const blob_write = Simuleos.Kernel.blob_write
const blob_read = Simuleos.Kernel.blob_read
# Canonical path helpers (SSOT for .simuleos/ directory layout)
const _tape_path = Simuleos.Kernel._tape_path

@testset "ScopeTapes + BlobStorage Query System" begin
    # Create temporary .simuleos structure for testing
    mktempdir() do tmpdir
        simuleos_dir = joinpath(tmpdir, ".simuleos")
        mkpath(simuleos_dir)

        # Create handlers to derive canonical paths
        test_session_name = "test_session"
        root = RootHandler(simuleos_dir)
        session = SessionHandler(root, test_session_name)
        tape_handler = TapeHandler(session)

        # Create sessions directory structure using canonical paths
        tape_path = _tape_path(tape_handler)
        tapes_dir = dirname(tape_path)
        mkpath(tapes_dir)

        # Write test blob through BlobStorage subsystem
        blob_key = ("test-blob", 1)
        test_data = Dict("foo" => 42, "bar" => [1, 2, 3])
        blob_ref_obj = blob_write(simuleos_dir, blob_key, test_data)
        blob_hash = blob_ref_obj.hash

        # Write test tape with two commits (JSONL = one JSON object per line)
        open(tape_path, "w") do io
            # First commit - must be a single line
            println(io, """{"type":"commit","session_label":"test_session","metadata":{"git_branch":"main"},"scopes":[{"label":"scope1","timestamp":"2024-01-15T10:30:00","variables":{"x":{"src_type":"Int64","src":"local","value":42},"y":{"src_type":"Vector{Float64}","src":"local","blob_ref":"$blob_hash"}},"labels":["iteration","step1"],"data":{"step":1}}],"blob_refs":["$blob_hash"],"commit_label":"first_commit"}""")
            # Second commit - must be a single line
            println(io, """{"type":"commit","session_label":"test_session","metadata":{"git_branch":"main"},"scopes":[{"label":"scope2","timestamp":"2024-01-15T10:31:00","variables":{"z":{"src_type":"String","src":"global","value":"hello"}}}],"blob_refs":[]}""")
        end

        @testset "BlobStorage" begin
            @test blob_ref(blob_key) isa BlobRef
            @test blob_ref(blob_key).hash == blob_hash
            @test exists(simuleos_dir, blob_ref_obj)
            @test exists(simuleos_dir, blob_key)
            @test blob_read(simuleos_dir, blob_ref_obj) == test_data
            @test blob_read(simuleos_dir, blob_key) == test_data

            @test_throws Exception blob_write(simuleos_dir, blob_key, Dict("foo" => 99))
            overwritten = Dict("foo" => 99)
            force_ref = blob_write(simuleos_dir, blob_key, overwritten; overwrite=true)
            @test force_ref.hash == blob_hash
            @test blob_read(simuleos_dir, force_ref) == overwritten
        end

        @testset "Handlers" begin
            @testset "RootHandler" begin
                @test root.path == simuleos_dir
            end

            @testset "sessions()" begin
                sess_list = collect(sessions(root))
                @test length(sess_list) == 1
                @test sess_list[1].label == test_session_name
                @test sess_list[1].root === root
            end

            @testset "tape()" begin
                sess = first(sessions(root))
                t = tape(sess)
                @test t isa TapeHandler
                @test t.session === sess
                @test exists(t)
            end
        end

        @testset "Raw Loaders" begin
            sess = first(sessions(root))
            t = tape(sess)

            @testset "iterate_raw_tape()" begin
                commits = collect(iterate_raw_tape(t))
                @test length(commits) == 2
                @test commits[1]["session_label"] == "test_session"
                @test commits[1]["commit_label"] == "first_commit"
                @test commits[2]["session_label"] == "test_session"
                @test !haskey(commits[2], "commit_label") || isempty(commits[2]["commit_label"])
            end
        end

        @testset "Typed Records" begin
            sess = first(sessions(root))
            t = tape(sess)

            @testset "CommitRecord" begin
                commits = collect(iterate_tape(t))
                @test length(commits) == 2

                c1 = commits[1]
                @test c1 isa CommitRecord
                @test c1.session_label == "test_session"
                @test c1.commit_label == "first_commit"
                @test c1.metadata["git_branch"] == "main"
                @test c1.blob_refs == [blob_hash]

                c2 = commits[2]
                @test c2.session_label == "test_session"
                @test isempty(c2.blob_refs)
            end

            @testset "ScopeRecord" begin
                commits = collect(iterate_tape(t))
                c1 = commits[1]

                @test length(c1.scopes) == 1

                s = c1.scopes[1]
                @test s isa ScopeRecord
                @test s.label == "scope1"
                @test s.timestamp == DateTime(2024, 1, 15, 10, 30, 0)
                @test s.labels == ["iteration", "step1"]
                @test s.data["step"] == 1
            end

            @testset "VariableRecord" begin
                commits = collect(iterate_tape(t))
                c1 = commits[1]
                s = c1.scopes[1]

                @test length(s.variables) == 2

                # Find x and y variables
                var_x = nothing
                var_y = nothing
                for v in s.variables
                    if v.name == "x"
                        var_x = v
                    elseif v.name == "y"
                        var_y = v
                    end
                end

                @test !isnothing(var_x)
                @test !isnothing(var_y)

                # Test x (inline value)
                @test var_x isa VariableRecord
                @test var_x.src_type == "Int64"
                @test var_x.src == :local
                @test var_x.value == 42
                @test isnothing(var_x.blob_ref)

                # Test y (blob reference)
                @test var_y.src_type == "Vector{Float64}"
                @test var_y.src == :local
                @test isnothing(var_y.value)
                @test var_y.blob_ref == blob_hash
            end
        end

        @testset "Empty cases" begin
            # Empty sessions directory
            mktempdir() do empty_dir
                empty_simuleos = joinpath(empty_dir, ".simuleos")
                mkpath(empty_simuleos)

                root = RootHandler(empty_simuleos)
                @test isempty(collect(sessions(root)))
            end

            # Non-existent sessions directory
            mktempdir() do no_sessions_dir
                root = RootHandler(no_sessions_dir)
                @test isempty(collect(sessions(root)))
            end
        end
    end
end

@testset "BlobStorage SimOs wrappers" begin
    mktempdir() do project_root
        simuleos_dir = joinpath(project_root, ".simuleos")
        mkpath(simuleos_dir)
        sim = Simuleos.Kernel.SimOs(project_root = project_root)
        sim._project = Simuleos.Kernel.Project(
            id = "test-project",
            root_path = project_root,
            simuleos_dir = simuleos_dir
        )

        key = ("simos", :blob)
        value = Dict(:a => 1, :b => [2, 3])
        ref = blob_write(sim, key, value)

        @test ref isa BlobRef
        @test blob_read(sim, key) == value
        @test blob_read(sim, ref) == value
    end
end
