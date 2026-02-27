@testset "Recording Primitives" begin
    Kernel = Simuleos.Kernel

    @testset "RecordRef constructor and string" begin
        ref = Kernel.RecordRef("abcdef123456789012345678901234567890abcd", "abcdef123456")
        @test ref.hash == "abcdef123456789012345678901234567890abcd"
        @test ref.short == "abcdef123456"
        @test string(ref) == "abcdef123456"
        @test sprint(show, ref) == "RecordRef(abcdef123456)"
    end

    @testset "record_content_hash determinism" begin
        data1 = Dict{String, Any}("a" => 1, "b" => "hello", "c" => [1, 2, 3])
        data2 = Dict{String, Any}("b" => "hello", "a" => 1, "c" => [1, 2, 3])

        h1 = Kernel.record_content_hash(data1)
        h2 = Kernel.record_content_hash(data2)
        @test h1 == h2  # same data, different insertion order → same hash
        @test length(h1) == 40  # SHA-1 hex

        # Different data → different hash
        data3 = Dict{String, Any}("a" => 2, "b" => "hello", "c" => [1, 2, 3])
        h3 = Kernel.record_content_hash(data3)
        @test h3 != h1
    end

    @testset "record_ref builds RecordRef" begin
        data = Dict{String, Any}("key" => "value")
        ref = Kernel.record_ref(data)
        @test ref isa Kernel.RecordRef
        @test length(ref.hash) == 40
        @test length(ref.short) == Kernel.RECORD_REF_SHORT_LEN
        @test startswith(ref.hash, ref.short)
    end

    @testset "record_write and record_resolve round-trip" begin
        with_test_context() do ctx
            tape_dir = joinpath(ctx[:project_path], ".simuleos", "test_tapes", "records")
            mkpath(tape_dir)
            tape = Kernel.TapeIO(tape_dir)

            payload = Dict{String, Any}(
                "context" => "test",
                "settings" => Dict{String, Any}("alpha" => 0.5),
                "execution" => Dict{String, Any}("file" => "script.jl", "line" => 42),
            )

            ref = Kernel.record_write(tape, payload)
            @test ref isa Kernel.RecordRef
            @test length(ref.hash) == 40

            # Resolve by full hash
            resolved = Kernel.record_resolve(tape, ref)
            @test resolved isa Dict{String, Any}
            @test resolved["context"] == "test"
            @test resolved["settings"]["alpha"] == 0.5

            # Resolve by RecordRef
            resolved2 = Kernel.record_resolve(tape, ref)
            @test resolved2 == resolved

            # Resolve by short prefix
            resolved3 = Kernel.record_resolve(tape, ref.short)
            @test resolved3 == resolved

            # Resolve nonexistent
            @test isnothing(Kernel.record_resolve(tape, "0000000000000000000000000000000000000000"))
            @test isnothing(Kernel.record_resolve(tape, ""))
        end
    end

    @testset "record_write deterministic ref for same data" begin
        with_test_context() do ctx
            tape_dir = joinpath(ctx[:project_path], ".simuleos", "test_tapes", "records2")
            mkpath(tape_dir)
            tape = Kernel.TapeIO(tape_dir)

            payload = Dict{String, Any}("x" => 42, "y" => "hello")
            ref1 = Kernel.record_write(tape, payload)
            ref2 = Kernel.record_write(tape, payload)
            @test ref1.hash == ref2.hash
        end
    end

    @testset "string interpolation with RecordRef" begin
        ref = Kernel.RecordRef("abcdef123456789012345678901234567890abcd", "abcdef123456")
        filename = "plot_$(ref).png"
        @test filename == "plot_abcdef123456.png"
    end

    @testset "generic_record ignored by commit iteration" begin
        with_test_context() do ctx
            tape_dir = joinpath(ctx[:project_path], ".simuleos", "test_tapes", "mixed")
            mkpath(tape_dir)
            tape = Kernel.TapeIO(tape_dir)

            # Write a generic record
            Kernel.record_write(tape, Dict{String, Any}("note" => "context snapshot"))

            # Write a commit
            scope = Kernel.ScopeSnapshot(["test"])
            commit = Kernel.CaptureTree("label", Kernel.PartialSnapshot[scope], Kernel.CaptureTree[], Dict{String, Any}())
            Kernel.commit_to_tape!(tape, commit)

            # Filter for commits only — generic_record should not appear
            commits = Dict{String, Any}[]
            for rec in Kernel.each_tape_records_filtered(tape;
                    json_filter = (obj, ctx) -> get(obj, "type", "") == "commit")
                push!(commits, rec)
            end
            @test length(commits) == 1
            @test commits[1]["type"] == "commit"
        end
    end

    @testset "_write_json_sorted determinism" begin
        d = Dict{String, Any}("z" => 1, "a" => 2, "m" => Dict{String, Any}("b" => 3, "a" => 4))
        s = Kernel._to_json_string_sorted(d)
        @test s == "{\"a\":2,\"m\":{\"a\":4,\"b\":3},\"z\":1}"

        # Verify same output regardless of insertion order
        d2 = Dict{String, Any}("a" => 2, "z" => 1, "m" => Dict{String, Any}("a" => 4, "b" => 3))
        s2 = Kernel._to_json_string_sorted(d2)
        @test s == s2
    end
end
