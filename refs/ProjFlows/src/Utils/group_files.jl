function group_files(freedim, dir; 
        filter = (filename) -> true
    )
    freedim = string(freedim)
    files = Dict()
    for filename in readdir(dir) |> sort
        !filter(filename) && continue
        
        ret = tryparse_dfname(filename)
        isnothing(ret) && continue
        head, params, ext = ret

        !haskey(params, freedim) && continue
        freedim_val = params[freedim]
        delete!(params, freedim)

        f = get!(files, (freedim, head, params, ext), Dict())
        f[freedim_val] = joinpath(dir, filename)
    end
    files
end