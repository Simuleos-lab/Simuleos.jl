using Test
using Simuleos

@testset "Metadata Capture" begin
    # Test with a script path in the current repository
    script_path = @__FILE__
    
    meta = Simuleos._capture_metadata(script_path)
    
    @testset "Basic metadata fields" begin
        @test haskey(meta, "timestamp")
        @test haskey(meta, "julia_version")
        @test haskey(meta, "hostname")
        @test haskey(meta, "script_path")
        @test meta["script_path"] == script_path
        @test meta["julia_version"] == string(VERSION)
        @test !isempty(meta["hostname"])
    end
    
    @testset "Git metadata fields" begin
        @test haskey(meta, "git_commit")
        @test haskey(meta, "git_dirty")
        
        # Since we're in a git repository, these should have values
        # (not nothing, unless git is not available)
        if meta["git_commit"] !== nothing
            @test meta["git_commit"] isa AbstractString
            @test length(meta["git_commit"]) == 40  # SHA-1 hash length
            # Test it's a valid hex string
            @test all(c -> c in "0123456789abcdef", meta["git_commit"])
        end
        
        if meta["git_dirty"] !== nothing
            @test typeof(meta["git_dirty"]) == Bool
        end
    end
    
    @testset "Empty script directory handling" begin
        # Test with empty string path (should use pwd)
        meta_empty = Simuleos._capture_metadata("")
        @test haskey(meta_empty, "git_commit")
        @test haskey(meta_empty, "git_dirty")
    end
    
    @testset "Non-git directory handling" begin
        # Create a temporary non-git directory
        tmpdir = mktempdir()
        try
            tmpfile = joinpath(tmpdir, "test.jl")
            write(tmpfile, "# test")
            
            meta_nongit = Simuleos._capture_metadata(tmpfile)
            # Should handle gracefully and set to nothing
            @test meta_nongit["git_commit"] === nothing
            @test meta_nongit["git_dirty"] === nothing
        finally
            rm(tmpdir, recursive=true)
        end
    end
end
