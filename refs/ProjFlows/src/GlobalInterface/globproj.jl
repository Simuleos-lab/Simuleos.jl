const __PROJ = AbstractProject[]

function globproj()
    isempty(__PROJ) && error("Project not set!, see `globproj!`")
    return first(__PROJ)
end

function globproj!(p::AbstractProject)
    empty!(__PROJ)
    push!(__PROJ, p)
    return p
end

function withproj(f::Function, p1::AbstractProject)
    p0 = globproj()
    ret = nothing
    try
        globproj!(p1)
        ret = f()
        finally; globproj!(p0)
    end
    return ret
end