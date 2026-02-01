using ProjAssistant
using Test
using Plots
ENV["GKSwstype"]="nul" # avoid external display

@testset "ProjAssistant.jl" begin
    include("cache_tests.jl")
    include("proj_gen_tests.jl")
end
