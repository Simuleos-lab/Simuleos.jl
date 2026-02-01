using Bloberias
using Base.Threads
using Random
using Test
using Aqua

# .-- . -. - .--..- -- .- - --..-.-.- .- -.--
# TODO: Use aqua

# .-- . -. - .--..- -- .- - --..-.-.- .- -.--
@testset "Bloberias.jl" begin
    ## .-- . -. - .--..- -- .- - --..-.-.- .- -.--
    B_ROOT = joinpath(tempname(), "B")
    atexit(() -> rm(B_ROOT; force = true, recursive = true)) 

    # Aqua
    # TODO: fix Aqua tests
    # Aqua.test_all(Bloberias;
        # ambiguities=(exclude=[SomePackage.some_function], broken=true),
        # stale_deps=(ignore=[:SomePackage],),
        # deps_compat=(ignore=[:SomeOtherPackage],),
        # piracies=false,
    # )

    try

        ## .-- . -. - .--..- -- .
        println("\n", "-"^40)
        @info("Test AbstractBlob interface!")
        let
            B = Bloberia(B_ROOT)
            rm(B)
            bb = BlobBatch(B, "bb")
            b = bBlob(bb, 0)
            
            ab = b
            for ab in [B, bb, b]
                @show typeof(ab)
                # set to depot
                val0 = rand()
                val = Bloberias._get_depotdisk_blob!(ab, "meta", "num") do
                    val0
                end
                @test val == val0

                # read depot hits
                val = Bloberias._getindex_depot_blob(ab, "meta", "num") 
                @test val == val0

                # serialize
                Bloberias._serialize_depot_frame(ab, "meta")
                
                # empty depot
                Bloberias._empty_depot!(ab)

                # read depot misses
                val = Bloberias._get_depot_blob(ab, "meta", "num") do
                    -1
                end
                @test val == -1
                
                # read from disk
                val = Bloberias._get_depotdisk_blob(ab, "meta", "num") do
                    -1
                end
                @test val == val0
            end
        end

        ## .-- . -. - .--..- -- .
        println("\n", "-"^40)
        @info("Test mergeblobs!")
        let
            B = Bloberia(B_ROOT)
            rm(B)
            bb = blobbatch!(B, "bb0")
            b = rblob!(bb)
            for ab in [b, bb, B]
                @test get(ab, "key", -1) === -1 # missing
                mergeblobs!(ab; lk = true, mk = true) do rfr, dfr
                    @test isnothing(dfr)
                    rfr["key"] = 1
                    return nothing
                end
                empty_depot!(ab)
                @test get(ab, "key", -1) === 1
            end
            nothing
        end

        ## .-- . -. - .--..- -- .
        println("\n", "-"^40)
        @info("Test threaded iterator")
        let
            B = Bloberia(B_ROOT)
            rm(B)

            nbbs = 10
            bs_per_bb = 10
            for bbi in 1:nbbs
                bb = blobbatch!(B, "db$bbi")
                for bi in 1:bs_per_bb
                    b = blob!(bb, bi)
                    b["rand"] = rand()
                end
                serialize!(bb)
            end
            @test batchcount(B) == nbbs

            # serial
            _wt = 0.2
            _t = @elapsed foreach_batch(B; 
                ch_size = nthreads(),
                n_tasks = 1
            ) do bb
                @show threadid()
                sleep(_wt)
            end
            @show _t
            @test _t >= nbbs * _wt

            # threaded
            if nthreads() > 1
                _wt = 0.2
                _t = @elapsed foreach_batch(B; 
                    ch_size = nthreads(),
                    n_tasks = nbbs
                ) do bb
                    @show threadid()
                    sleep(_wt)
                end
                @show _t
                @test _t <= nbbs * _wt
            end

        end
        
        ## .-- . -. - .--..- -- .
        println("\n", "-"^40)
        @info("Test RefCacher")
        # TODO: fix tests
        let

            B = Bloberia(B_ROOT)
            rm(B)

            # write
            _refs = BlobyRef[]
            _acc0 = 0.0
            bb = blobbatch!(B, "db")
            for bi in 1:100
                b = blob!(bb, bi)
                rn = rand()
                _acc0 += rn
                b["rand"] = rn
                ref = blobyref(b, "rand"; rT = Float64, abs = true)
                push!(_refs, ref)
            end
            serialize!(bb)

            # test iterato
            _acc = 0
            for _bb in B
                for b in _bb
                    _acc += b["rand"]
                end
            end
            @test abs(_acc - _acc0) < 1e-6
            
            # no cache
            _acc = 0.0
            @time _alloc_non_cached = @allocated for ref in _refs
                _acc += ref[]
            end
            @show _alloc_non_cached
            @test abs(_acc - _acc0) < 1e-6

            # cache
            _acc = 0.0
            rc = RefCacher()
            @time _alloc_cached = @allocated for ref in _refs
                _acc += rc[ref]
            end
            @show _alloc_cached
            @test abs(_acc - _acc0) < 1e-6

            # rel ref
            _acc = 0.0
            @time _alloc_rel = @allocated for ref in _refs
                _acc += bb[ref]
            end
            @show _alloc_rel
            @test abs(_acc - _acc0) < 1e-6

            @test _alloc_rel < _alloc_cached 
            @test _alloc_cached < _alloc_non_cached 
        end
        
        ## .-- . -. - .--..- -- .
        println("\n", "-"^40)
        @info("Test blobyref")
        let
            ## Ram only
            B = Bloberia(B_ROOT)
            rc = RefCacher()
            rm(B)

            ref = blobyref(B)
            @test B.root == ref[].root      # abs deref
            @test B.root == B[ref].root     # rel deref
            @test B.root == rc[ref].root     # rel deref
            
            # non absolute path
            ref = blobyref(B; abs = false)
            @test B.root == ref[].root       # abs deref (bloberia is the root, always abs)
            @test B.root == B[ref].root      # rel deref
            
            bb = blobbatch!(B, "bb")
            # rm(bb)
            ref = blobyref(bb; abs = true)
            @test bb.root == ref[].root       # abs deref
            @test bb.root == bb[ref].root     # rel deref
            @test bb.root == B[ref].root      # rel deref
            @test bb.root == rc[ref].root     # rel deref
            
            # non absolute path
            ref = blobyref(bb; abs = false)
            @test_throws ["B.root"] bb.root == ref[].root  # fail (B missing)
            @test bb.root == bb[ref].root     # rel deref
            @test bb.root == B[ref].root      # rel deref
        
            b = blob!(bb, 0)
            ref = blobyref(b)
            @test b.bb.root == ref[].bb.root    # abs deref
            @test b.bb.root == b[ref].bb.root   # rel deref
            @test b.uuid == ref[].uuid          # abs deref
            @test b.uuid == bb[ref].uuid        # rel deref
            @test b.uuid == rc[ref].uuid        # rel deref
            
            # non absolute path
            ref = blobyref(b; abs = false)
            @test_throws ["B.root"] b.uuid == ref[].uuid  # fail (B missing)
            @test b.uuid == bb[ref].uuid       # rel deref
            @test b.bb.root == b[ref].bb.root   # rel deref
            
            # blob(ref) only work if disk version exist
            # the same for ref[]
            # but blob!(ref) creates a new blob
            ref = blobyref(b)
            b1 = blob(ref)                      
            @test b.uuid == b1.uuid             #
            @test b.bb.root == b1.bb.root       #
            @test b.bb.root == b[ref].bb.root   # rel deref
            @test b.uuid == b1[ref].uuid        # rel deref
            @test b.uuid == rc[ref].uuid        # rel deref
        
            ref = blobyref(b; abs = false)
            @test_throws ["B.root"] blob(ref)     # fail (B missing)             
        
            # Vals
            rm(B)
            empty!(B)
            empty!(bb)
        
            ref = blobyref(B, "ref.test"; rT = Int)
            B["ref.test"] = 1
            @test B[ref] == 1
            # @test_throws ["not found", "No such file"] rc[ref] == 1  # this fail because values needs disk
            @test_throws Exception rc[ref] == 1  # this fail because values needs disk
            
            ## Disk interactions
            rm(B)
            empty!(B)
            empty!(bb)
            empty!(rc)
            bb = blobbatch!(B, "db")
            b = blob!(bb, 0)
            for ab in [B, bb, b]
                # @info "Testing" typeof(ab)
                ref = blobyref(ab, "ref.test"; rT = Int)
                # @test_throws ["not found", "No such file"] ref[] # val does not exist anywhere
                @test_throws Exception ref[] # val does not exist anywhere
                ab["ref.test"] = 1
                @test ab[ref] == 1 # now it exist on ram
                ab[ref] = 2
                # @test_throws ["not found", "No such file"] ref[] # but ram is unreachable 
                @test_throws Exception ref[] # but ram is unreachable 
                @test ab[ref] == 2 # at least you do a relative deref
                
                serialize!(ab; force = true)
                empty!(ab) # clear ram
                
                # load from disk
                @test ref[] == 2
                @test ab[ref] == 2
                @test rc[ref] == 2
            end
        end

        ## .-- . -. - .--..- -- .
        println("\n", "-"^40)
        @info("Test hashio!")
        let
            B = Bloberia(B_ROOT)
            rm(B)
            # ram only
            bb = blobbatch!(B, "bb")
            b = blob!(bb, 0)
        
            Random.seed!(123)
            for ab in [b, bb, B]
                @show typeof(ab)
                for it in 1:10
                    mat = rand(10,10)
                    # abs
                    ref = hashio!(ab, mat, :get!)
                    show(ref); println()
                    @test objectid(ab[ref]) == objectid(mat)
                    serialize!(ab; force = true)
                    @test objectid(ref[]) != objectid(mat)
                    @test mat == ab[ref]
                    @test mat == ref[]
                    
                    # rel
                    ref = hashio!(ab, mat; abs = false)
                    show(ref); println()
                    @test objectid(ab[ref]) == objectid(mat) # still the same object
                    @test mat == ab[ref]
                end 
            end
        end
        
        ## .-- . -. - .--..- -- .- - --..-.-.- .- -.--
        println("\n", "-"^40)
        @info("Test get interface")
        let
            B = Bloberia(B_ROOT)
            rm(B)
            bb = blobbatch!(B, "test")
            b = rblob!(bb)
            for ab in [B, bb, b]
                # ram only
                # @test_throws ["not found", "No such file"] ab["val"]
                @test_throws Exception ab["val"]
                @test get(ab, "val", 0) === 0
            end
        end

        ## .-- . -. - .--..- -- .
        println("\n", "-"^40)
        @info("Test getindex/setindex! interface")
        let
            B = Bloberia(B_ROOT)
            rm(B)
            # ram only
            bb = blobbatch!(B, "bb")
            b = blob!(bb, 0)
            for bobj in [B, bb, b]
                _runned = get!(bobj, "key0", 1)
                @test _runned == 1
                # ignore defaults (data on ram)
                _runned = get!(bobj, "key0", 2)
                @test _runned == 1
                _runned = get(bobj, "key0", 3)
                @test _runned == 1
            end
            serialize!(B)
            serialize!(bb)
        
            # load
            empty_depot!(B)
            empty_depot!(bb)
            @test !hasframe_depot(B)
            @test !hasframe_depot(bb)
            @test hasframe_disk(B)
            @test hasframe_disk(bb)
            for bobj in [B, bb, b]
                # ignore defaults (data on disk)
                _runned = get!(bobj, "key0", 2)
                @test _runned == 1
                _runned = get(bobj, "key0", 3)
                @test _runned == 1
            end
        end

        ## .-- . -. - .--..- -- .
        println("\n")
        
    finally
        rm(B_ROOT; recursive = true, force = true)
    end
end

## .-- . -. - .--..- -- .- - --..-.-.- .- -.--
