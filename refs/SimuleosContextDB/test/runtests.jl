using SimuleosContextDB
using Test

@testset "ContextNode behaves like a Dict" begin
    d = ContextNode()

    # basic size/emptiness
    @test isempty(d)
    @test length(d) == 0

    # setindex! / getindex
    d["a"] = 1
    d["b"] = 2
    @test !isempty(d)
    @test length(d) == 2
    @test d["a"] == 1
    @test d["b"] == 2

    # overwriting existing key doesn't change number of keys
    d["a"] = 10
    @test d["a"] == 10
    @test length(d) == 2

    # haskey, get (non-inserting), get! (inserting)
    @test haskey(d, "a")
    @test !haskey(d, "zzz")
    @test get(d, "zzz", 99) == 99
    @test !haskey(d, "zzz")              # get does NOT insert
    @test get!(d, "zzz", 42) == 42       # get! inserts default
    @test haskey(d, "zzz")
    @test d["zzz"] == 42

    # indexing a missing key should throw KeyError
    @test_throws KeyError d["missing_key"]

    # keys / values / pairs / iteration
    ks = Set(keys(d))
    vs = Set(values(d))
    ps = Set(collect(pairs(d)))    # same as Set(collect(d))
    @test ks == Set(["a", "b", "zzz"])
    @test vs == Set([10, 2, 42])
    @test ps == Set(["a"=>10, "b"=>2, "zzz"=>42])

    # iteration yields Pair{K,V}
    for kv in d
        @test kv isa Pair
        @test kv.first in ks
        @test kv.second in vs
    end

    # copy makes an independent mutable dictionary
    # TODO: Think about the equal interface
    # d2 = copy(d)
    # @test d2 == d
    # d2["new"] = 7
    # @test haskey(d2, "new")
    # @test !haskey(d, "new")

    # # merge (pure) / merge! (in-place)
    # TODO: Think about the merge interface
    # d3 = merge(d, Dict("x"=>1, "a"=>100))
    # @test d3["a"] == 100 && d3["x"] == 1
    # @test d["a"] == 10                  # original unchanged by merge

    # merge!(d, Dict("x"=>1, "a"=>100))
    # @test d["a"] == 100 && d["x"] == 1

    # # delete! / pop!
    # @test delete!(d, "x") === d         # returns the dict per Base API
    # @test !haskey(d, "x")

    # v = pop!(d, "a")
    # @test v == 100
    # @test !haskey(d, "a")

    # @test_throws KeyError pop!(d, "nope")
    # @test pop!(d, "nope", "default") == "default"

    # # empty!
    # TODO: Think about the empty! interface
    # empty!(d)
    # @test isempty(d)
    # @test length(d) == 0

    # # conversion via iteration should work
    # d4 = new_ContextNode()
    # d4["p"] = 1; d4["q"] = 2
    # base_dict = Dict(d4)               # uses iteration of pairs
    # @test base_dict == Dict("p"=>1, "q"=>2)
end