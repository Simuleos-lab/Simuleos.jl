Base.iterate(s::Scope) = iterate(s.sc)
Base.iterate(s::Scope, state) = iterate(s.sc, state)

Base.getindex(s::Scope, key::String) = s.sc[key]
Base.setindex!(s::Scope, val::SimuleosScopeVariable, key::String) = (s.sc[key] = val)

Base.haskey(s::Scope, key::String) = haskey(s.sc, key)
Base.keys(s::Scope) = keys(s.sc)
Base.values(s::Scope) = values(s.sc)
Base.pairs(s::Scope) = pairs(s.sc)
Base.length(s::Scope) = length(s.sc)
Base.isempty(s::Scope) = isempty(s.sc)

Base.eltype(::Type{Scope}) = eltype(typeof(s.sc))
Base.IteratorSize(::Type{Scope}) = Base.HasLength()

Base.get(s::Scope, key::String, default) = get(s.sc, key, default)
Base.get!(s::Scope, key::String, default) = get!(s.sc, key, default)
Base.pop!(s::Scope, key::String, default=nothing) = pop!(s.sc, key, default)
Base.empty!(s::Scope) = empty!(s.sc)

Base.in(key::String, s::Scope) = key in s.sc
Base.merge!(s::Scope, others...) = merge!(s.sc, (x.sc for x in others)...)
Base.merge(s::Scope, others...) = Scope(merge(s.sc, (x.sc for x in others)...))

import Base.filter
function filter(f::Function, s::Scope)
    new_sc = OrderedDict{String, SimuleosScopeVariable}()
    for (key, scv) in s
        f(scv) || continue
        new_sc[key] = scv
    end
    Scope(new_sc)
end

# ---.>._- - -. -->>> -- -_.... < - 
# TODO/ prettyprint
function Base.show(io::IO, sc::Scope)
    print(io, "🌐 Scope with $(length(sc.sc)) variable(s):\n")

    # format tape variables
    key_map = map(collect(keys(sc))) do key
        sc_is_labelkey(key) && return (key, "st_label")
        return (key, key)
    end
    sort!(key_map; by = (m) -> m[1])

    for (ri, (key, keystr)) in enumerate(key_map)
        svc = sc[key]
        

        printstyled(io, rpad(string("[", svc.src, "]"), 8); color = :normal)
        print(io, " ")
        if (keystr == "ST_INIT_WH")
            printstyled(io, rpad(keystr, 20); color = :yellow)
        elseif (keystr == "ST_COMMIT_WH")
            printstyled(io, rpad(keystr, 20); color = :yellow)
        elseif (keystr == "st_label")
            printstyled(io, rpad(keystr, 20); color = :yellow)
        else
            printstyled(io, rpad(keystr, 20); color = :green)
        end
        print(io, " ")
        # if (svc.st_class === :primitive)
        #     printstyled(io, repr(svc.val); color = :normal)
        # else
        #     printstyled(io, rpad(first(repr(svc.jl_type), 25), 20); color = :light_blue)
        #     print(io, " ")
        #     printstyled(io, svc.st_class; color = :green)
        #     print(io, " ")
        #     printstyled(io, svc.st_hash; color = :blue)
        # end
        println(io)
    end
end

# ---.>._- - -. -->>> -- -_.... < - 
Base.hash
function Base.hash(sc::Scope, h::UInt = UInt(0))
    hs = zeros(UInt, length(sc))
    i = 1
    for scv in values(sc)
        hs[i] = hash(scv)
        i += 1
    end
    sort!(hs)
    return hash(hs, hash(:Scope, h))
end