using Simuleos
using Test
using Dates
using Serialization

@testset "Query System" begin
    # Create temporary .simuleos structure for testing
    mktempdir() do tmpdir
        simuleos_dir = joinpath(tmpdir, ".simuleos")
        mkpath(simuleos_dir)

        # Create sessions directory structure
        test_session_name = "test_session"
        session_dir = joinpath(simuleos_dir, "sessions", test_session_name)
        tapes_dir = joinpath(session_dir, "tapes")
        mkpath(tapes_dir)

        # Create blobs directory
        blobs_dir = joinpath(simuleos_dir, "blobs")
        mkpath(blobs_dir)

        # Write a test blob
        test_data = Dict("foo" => 42, "bar" => [1, 2, 3])
        blob_hash = "abc123def456"
        blob_path = joinpath(blobs_dir, "$(blob_hash).jls")
        open(blob_path, "w") do io
            serialize(io, test_data)
        end

        # Write test tape with two commits (JSONL = one JSON object per line)
        tape_path = joinpath(tapes_dir, "context.tape.jsonl")
        open(tape_path, "w") do io
            # First commit - must be a single line
            println(io, """{"type":"commit","session_label":"test_session","metadata":{"git_branch":"main"},"scopes":[{"label":"scope1","timestamp":"2024-01-15T10:30:00","variables":{"x":{"src_type":"Int64","src":"local","value":42},"y":{"src_type":"Vector{Float64}","src":"local","blob_ref":"abc123def456"}},"labels":["iteration","step1"],"data":{"step":1}}],"blob_refs":["abc123def456"],"commit_label":"first_commit"}""")
            # Second commit - must be a single line
            println(io, """{"type":"commit","session_label":"test_session","metadata":{"git_branch":"main"},"scopes":[{"label":"scope2","timestamp":"2024-01-15T10:31:00","variables":{"z":{"src_type":"String","src":"global","value":"hello"}}}],"blob_refs":[]}""")
        end

        @testset "Handlers" begin
            root = RootHandler(simuleos_dir)

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

            @testset "blob()" begin
                b = blob(root, blob_hash)
                @test b isa BlobHandler
                @test b.sha1 == blob_hash
                @test exists(b)

                # Non-existent blob
                b2 = blob(root, "nonexistent")
                @test !exists(b2)
            end
        end

        @testset "Raw Loaders" begin
            root = RootHandler(simuleos_dir)
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

            @testset "load_raw_blob()" begin
                b = blob(root, blob_hash)
                data = load_raw_blob(b)
                @test data == test_data
            end
        end

        @testset "Wrappers" begin
            root = RootHandler(simuleos_dir)
            sess = first(sessions(root))
            t = tape(sess)

            @testset "CommitWrapper" begin
                commits = collect(iterate_tape(t))
                @test length(commits) == 2

                c1 = commits[1]
                @test session_label(c1) == "test_session"
                @test commit_label(c1) == "first_commit"
                @test metadata(c1)["git_branch"] == "main"
                @test blob_refs(c1) == ["abc123def456"]

                c2 = commits[2]
                @test session_label(c2) == "test_session"
                @test isempty(blob_refs(c2))
            end

            @testset "ScopeWrapper" begin
                commits = collect(iterate_tape(t))
                c1 = commits[1]

                scope_list = collect(scopes(c1))
                @test length(scope_list) == 1

                s = scope_list[1]
                @test label(s) == "scope1"
                @test timestamp(s) == DateTime(2024, 1, 15, 10, 30, 0)
                @test labels(s) == ["iteration", "step1"]
                @test data(s)["step"] == 1
            end

            @testset "VariableWrapper" begin
                commits = collect(iterate_tape(t))
                c1 = commits[1]
                s = first(scopes(c1))

                var_list = collect(variables(s))
                @test length(var_list) == 2

                # Find x and y variables
                var_x = nothing
                var_y = nothing
                for v in var_list
                    if name(v) == "x"
                        var_x = v
                    elseif name(v) == "y"
                        var_y = v
                    end
                end

                @test !isnothing(var_x)
                @test !isnothing(var_y)

                # Test x (inline value)
                @test src_type(var_x) == "Int64"
                @test src(var_x) == :local
                @test value(var_x) == 42
                @test isnothing(blob_ref(var_x))

                # Test y (blob reference)
                @test src_type(var_y) == "Vector{Float64}"
                @test src(var_y) == :local
                @test isnothing(value(var_y))
                @test blob_ref(var_y) == "abc123def456"
            end

            @testset "BlobWrapper" begin
                b = blob(root, blob_hash)
                bw = load_blob(b)
                @test bw isa BlobWrapper
                @test data(bw) == test_data
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
