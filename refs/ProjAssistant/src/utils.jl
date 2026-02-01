"""
    give the error text as string
"""
function err_str(err; max_len = 10000)
    s = sprint(showerror, err, catch_backtrace())
    return length(s) > max_len ? s[1:max_len] * "\n[...]" : s
end

## ----------------------------------------------------------------------------
function _extract_dir(args...)
    isempty(args) && return ("", args)
    path = ""
    for (i, arg) in enumerate(args)
        !(arg isa Vector{<:AbstractString}) && return (path, args[i:end])
        for dir in arg
            path = joinpath(path, dir)
        end
    end
    return (path, tuple())
end