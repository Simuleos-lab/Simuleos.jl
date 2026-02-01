## --------------------------------------------------------
function test_blobdb(root::AbstractString; 
        nbatches = 5,
        nblobs = 10,
        datfun = () -> rand(100), 
        verbose = false,
    )
    mkpath(root)
    # create blobbatches
    info_t = -1.0
    for it in 1:nbatches
        bdir = joinpath(root, string("batch_", it))
        bb = BlobBatch(bdir)
        # fill some stuff
        bb["meta"]["time"] = time()
        bb[1] = [] # create
        for _ in 1:nblobs
            obj = Dict("dat" => datfun(), "time" => time())
            push!(bb[1], obj)
        end
        serialize(bb);
        verbose && if time() > info_t
            print("creating blobs: ", it, "/", nbatches, "             \r")
            info_t = time() + 1.0
        end
    end
    verbose && println(" "^80)
    return root
end