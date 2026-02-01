using DataFileNames
import DataFileNames: parse_arg, _set_default_SEPS!, _SEPS
# using Random
using Test

## ------------------------------------------
# Custom type
struct Foo
    f::Float64
    i::Int
    s::String
end
DataFileNames.parse_arg(f::Foo) = (;f.f, f.i, f.s)

## ------------------------------------------
function _run_tests()
    # ------------------------------------------
    @info("Testing 'dfname' produces 'isvalid_dfname' names")

    for fn in [
            dfname("dat"), 
            dfname("dat", "test"), 
            dfname("dat", ".png"), 
            dfname("dat", ".gz.tar"), 
            dfname((;A = rand())), 
            dfname((;A = rand()), "png"), 
            dfname("dat", "dyn", (;ϵ = rand(), B = "main")), 
            dfname("dat", (;A = :v1), "png"), 
            dfname(["dir1", "dir2"], "dat", (;A = :v1), "png")
        ]
            isvalid = isvalid_dfname(fn)
            @info("Testing", fn, isvalid)
            @test isvalid
    end
    @test dfname() == ""
    @test dfname("") == ""
    println()

    # ------------------------------------------
    #  Test dfname
    @info("Testing dfname")
    @test dfname("dat") == "dat"
    @test dfname("dat") == dfname(:dat)

    @test dfname("dat", ".ext") != dfname("dat", "ext")
    @test dfname("dat", ".") == "dat."
    
    @test dfname("", "dat") == "dat"
    @test dfname("dat", "") == "dat"
    
    @test dfname("dat", (;A = 1)) == dfname("dat", :A => 1)
    @test dfname("dat", (;A = 1)) == dfname("dat", Dict(:A => 1))
    @test dfname("dat", "", (;A = 1)) == dfname("dat", (;A = 1))
    @test dfname("dat", (;A = 1), "") == dfname("dat", (;A = 1))
    @test dfname("dat", (;A = 1), ".ext") == dfname("dat", (;A = 1), "ext")

    @test basename(dfname(["dir"], "dat")) == "dat"
    @test dfname(["dir"], "dat") == joinpath("dir", "dat")
    @test dfname(["dir1", "dir2"], "dat") == joinpath("dir1", "dir2", "dat")
    @test dfname(["dir1"], ["dir2"], "dat") == joinpath("dir1", "dir2", "dat")
    println()

    # ------------------------------------------
    # Custom Type
    @info("Custom type")
    foo = Foo(1.0, 1, "hi")
    
    @test dfname(foo) == dfname(parse_arg(foo))
    @test dfname("bla", foo) == dfname("bla", parse_arg(foo))
    println()

    # ------------------------------------------
    # Parsing
    @info("Testing parse_dfname")
    let
        head = "dat"
        ext = ".jls"

        fname = dfname(head, ext)
        par_head, par_params, par_ext = parse_dfname(fname)
        @test head in par_head
        @test ext == par_ext

        # with dir
        fname = dfname([@__DIR__], head, ext)
        par_head, par_params, par_ext = parse_dfname(fname)
        @test head in par_head
        @test ext == par_ext
    end

    for it in 1:100
        head = [rand(-5:10), "Hello", rand()]
        params = (;S = "string", F = rand(), I = rand(-10:10))
        ext = ".ext"
        fname = dfname(head..., params, ext)
        par_head, par_params, par_ext = parse_dfname(fname)

        _isapprox(s1::String, s2::String) = (s1 == s2)
        _isapprox(v1, v2; atol = 1e-2) = isapprox(v1, v2; atol)
        
        @test length(head) == length(par_head)
        @test length(params) == length(par_params)

        @test all(_isapprox.(head, par_head))
        for (k, param) in pairs(params)
            kstr = string(k)
            @test haskey(par_params, kstr)
            par_param = par_params[kstr]
            @test all(_isapprox.(param, par_param))
        end
        @test length(par_ext) == length(ext) ?
            par_ext == ext : endswith(par_ext, ext)

        @test dfname(head..., params, ext) == dfname(par_head..., par_params, par_ext)
    end
    println()

    # ------------------------------------------
    # Try parse
    @test tryparse_dfname("Invalid=name") === nothing
        
    # ------------------------------------------
    # Create file
    @info("Testing creating a file")
    let
        file = dfname([tempdir()], "dat", (;I = rand(Int), F = rand()), "jls")
        @assert !isfile(file)
        @show file
        touch(file)
        @test isfile(file)
    end
end

## ------------------------------------------
@testset "DataFileNames.jl" begin

    # ------------------------------------------
    # Use default SEPS (mainly because ext sepataror)
    @info("Default separator")
    _set_default_SEPS!()
    _run_tests()

    # ------------------------------------------
    # Test custom separators
    println("\n"^3)
    @info("Custom separator")
    _set_default_SEPS!()
    _SEPS[:ELEMT_SEP] = _SEPS[:ELEMT_SEP]^2
    _SEPS[:PARAMS_LSEP] = _SEPS[:PARAMS_LSEP]^2
    _SEPS[:PARAMS_RSEP] = _SEPS[:PARAMS_RSEP]^2
    _run_tests()

end
