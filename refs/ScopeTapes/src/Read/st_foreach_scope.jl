## ---.-.- ...- -- .--- . .- .-. . ..- .--.-
struct _ForEachChannelReturn
    task::Task
    fn::String
    fi::Int
end

function foreach_scope(f::Function; 
        maxbatches = Int(1e10),
        maxscopes = Int(1e10),
        buffer_len = 10
    )
    
    config = st_config()
    rootdir = config["root.dir"]
    rb_man = st_manifest("registered.batches")
    filenames_::Vector{String} = get(rb_man, "registry", String[])
    scsdir = joinpath(rootdir, "scopes")
    isdir(scsdir) || return;

    # Step 2: Spawn tasks to load files in parallel
    batchcount = 0
    tasks_channel = Channel{_ForEachChannelReturn}(buffer_len) do _ch
        for (fi, name) in enumerate(filenames_)
            fn = joinpath(scsdir, name)
            endswith(fn, ".jld2") || continue
            batchcount < maxbatches || break;
            task = Threads.@spawn st_deserialize(fn, [])
            tcr = _ForEachChannelReturn(task, fn, fi)
            put!(_ch, tcr)
            batchcount += 1
        end
    end
    
    scopecount = 0
    for tcr in tasks_channel
        scopecount < maxscopes || break;
        scs = fetch(tcr.task)
        for sc in scs
            scopecount < maxscopes || break;
            ret = f(sc) 
            ret === :break && return
            ret === :breakbatch && break
            scopecount += 1
        end
    end
    @show batchcount
    @show scopecount
    return
end