using Test

const _K = Simuleos.Kernel
const _search = _K.jmespath_search

@testset "JMESPath" begin

    # ==========================================================
    @testset "field access" begin
        @test _search("a", Dict("a" => 1)) == 1
        @test _search("b", Dict("a" => 1)) === nothing
        @test _search("a", Dict("a" => "hello")) == "hello"
        @test _search("a", Dict("a" => nothing)) === nothing
        @test _search("a", Dict("a" => true)) === true
        @test _search("a", Dict("a" => false)) === false
        # non-dict input
        @test _search("a", [1, 2]) === nothing
        @test _search("a", 42) === nothing
    end

    # ==========================================================
    @testset "nested field access (sub-expression)" begin
        data = Dict("a" => Dict("b" => Dict("c" => "deep")))
        @test _search("a.b.c", data) == "deep"
        @test _search("a.b", data) == Dict("c" => "deep")
        @test _search("a.b.missing", data) === nothing
        @test _search("a.missing.c", data) === nothing
    end

    # ==========================================================
    @testset "array index" begin
        data = Dict("a" => [10, 20, 30])
        @test _search("a[0]", data) == 10
        @test _search("a[1]", data) == 20
        @test _search("a[2]", data) == 30
        @test _search("a[3]", data) === nothing
        # negative index
        @test _search("a[-1]", data) == 30
        @test _search("a[-2]", data) == 20
        @test _search("a[-3]", data) == 10
        @test _search("a[-4]", data) === nothing
        # index on non-array
        @test _search("a[0]", Dict("a" => "str")) === nothing
    end

    # ==========================================================
    @testset "list wildcard [*]" begin
        data = Dict("items" => [
            Dict("name" => "a", "v" => 1),
            Dict("name" => "b", "v" => 2),
        ])
        @test _search("items[*].name", data) == ["a", "b"]
        @test _search("items[*].v", data) == [1, 2]
        @test _search("items[*].missing", data) == []
    end

    # ==========================================================
    @testset "object wildcard *" begin
        data = Dict("a" => 1, "b" => 2, "c" => 3)
        result = _search("*", data)
        @test result isa Vector
        @test Set(result) == Set([1, 2, 3])
    end

    # ==========================================================
    @testset "flatten []" begin
        data = Dict("a" => [[1, 2], [3, 4], [5]])
        @test _search("a[]", data) == [1, 2, 3, 4, 5]
        # mixed nested/non-nested
        data2 = Dict("a" => [1, [2, 3], 4])
        @test _search("a[]", data2) == [1, 2, 3, 4]
    end

    # ==========================================================
    @testset "filter [?]" begin
        items = [
            Dict("name" => "x", "v" => 1),
            Dict("name" => "y", "v" => 2),
            Dict("name" => "z", "v" => 3),
        ]
        @test _search("[?v == `1`]", items) == [Dict("name" => "x", "v" => 1)]
        @test _search("[?v > `1`].name", items) == ["y", "z"]
        @test _search("[?v >= `2`].name", items) == ["y", "z"]
        @test _search("[?v < `2`].name", items) == ["x"]
        @test _search("[?v != `2`].name", items) == ["x", "z"]
        # string comparison
        @test _search("[?name == 'y']", items) == [Dict("name" => "y", "v" => 2)]
    end

    # ==========================================================
    @testset "nested filter with projection" begin
        data = Dict("scopes" => [
            Dict("labels" => ["main.summary"], "variables" => Dict("x" => 1)),
            Dict("labels" => ["main.sample"], "variables" => Dict("x" => 2)),
            Dict("labels" => ["main.sample"], "variables" => Dict("x" => 3)),
        ])
        @test _search("scopes[?labels[0] == 'main.sample'].variables.x", data) == [2, 3]
        @test _search("scopes[?labels[0] == 'main.summary'].variables.x", data) == [1]
        @test _search("scopes[?labels[0] == 'missing']", data) == []
    end

    # ==========================================================
    @testset "comparisons" begin
        data = Dict("x" => 5, "y" => 10, "s" => "hello")
        @test _search("x == `5`", data) === true
        @test _search("x != `5`", data) === false
        @test _search("x < y", data) === true
        @test _search("x > y", data) === false
        @test _search("x <= `5`", data) === true
        @test _search("x >= `5`", data) === true
        @test _search("s == 'hello'", data) === true
        @test _search("s == 'world'", data) === false
        # ordering on mixed types returns null
        @test _search("x < s", data) === nothing
    end

    # ==========================================================
    @testset "logical operators" begin
        data = Dict("a" => true, "b" => false, "x" => 1, "y" => 0)
        @test _search("a && b", data) === false
        @test _search("a || b", data) === true
        @test _search("!b", data) === true
        @test _search("!a", data) === false
        # short-circuit: && returns first falsy, || returns first truthy
        # JMESPath: all numbers (including 0) are truthy
        @test _search("x && y", data) == 0
        @test _search("y || x", data) == 0  # 0 is truthy, returns 0
        # false is falsy
        @test _search("b || x", data) == 1
    end

    # ==========================================================
    @testset "literals and raw strings" begin
        @test _search("`42`", Dict()) == 42
        @test _search("`true`", Dict()) === true
        @test _search("`false`", Dict()) === false
        @test _search("`null`", Dict()) === nothing
        @test _search("'hello'", Dict()) == "hello"
    end

    # ==========================================================
    @testset "empty expression returns data" begin
        data = Dict("a" => 1)
        @test _search("", data) == data
        @test _search("  ", data) == data
    end

    # ==========================================================
    @testset "quoted identifiers" begin
        data = Dict("my-field" => 1, "with spaces" => 2)
        @test _search("\"my-field\"", data) == 1
        @test _search("\"with spaces\"", data) == 2
    end

    # ==========================================================
    @testset "complex Simuleos-like queries" begin
        commit = Dict(
            "commit_label" => "uh1.fix.point.fba.v1.main",
            "class_id" => "rec.capture_commit",
            "metadata" => Dict(
                "git_commit" => "48e472a",
                "git_dirty" => false,
                "timestamp" => "2026-03-06T15:44:11",
            ),
            "scopes" => [
                Dict(
                    "labels" => ["main.summary"],
                    "class_id" => "snap.scope",
                    "variables" => Dict(
                        "N_SAMPLES" => Dict("value" => 3, "src_type" => "Int64"),
                        "df" => Dict("src_type" => "DataFrame", "blob_ref" => "abc123"),
                    ),
                    "metadata" => Dict("src_line" => 45),
                ),
                Dict(
                    "labels" => ["main.sample"],
                    "class_id" => "snap.scope",
                    "variables" => Dict(
                        "YA1" => Dict("value" => 2.14, "src_type" => "Float64"),
                        "df" => Dict("src_type" => "DataFrame", "blob_ref" => "def456"),
                    ),
                    "metadata" => Dict("src_line" => 55),
                ),
            ],
        )

        # Find scope labels
        @test _search("scopes[*].labels[0]", commit) == ["main.summary", "main.sample"]

        # Filter scopes by label
        @test _search("scopes[?labels[0] == 'main.sample'].variables.YA1.value", commit) == [2.14]

        # Navigate to specific scope variable
        @test _search("scopes[0].variables.N_SAMPLES.value", commit) == 3

        # Check metadata
        @test _search("metadata.git_dirty", commit) === false
        @test _search("metadata.git_commit", commit) == "48e472a"

        # Filter by nested metadata
        @test _search("scopes[?metadata.src_line == `55`].labels[0]", commit) == ["main.sample"]

        # Find blob refs
        @test _search("scopes[*].variables.df.blob_ref", commit) == ["abc123", "def456"]
    end

    # ==========================================================
    @testset "parse errors" begin
        @test_throws ErrorException _search("[", Dict())
        @test_throws ErrorException _search("a.", Dict())
        @test_throws ErrorException _search("[?", Dict())
        @test_throws ErrorException _search("=", Dict())
    end

end
