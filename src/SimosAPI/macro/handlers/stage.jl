function _simos_stage_mark_vars(args, cmd::String, capture_field::Symbol)
    stmts = Expr[]
    for v in args
        v isa Symbol || error("@simos $(cmd) expects variable names, got: $v")
        push!(stmts, quote
            let sim = $(_SimKrn)._get_sim()
                isnothing(sim.worksession) && error("No active session. Call `@simos session.init(...)` first.")
                push!(getfield(sim.worksession.capture_policy, $(QuoteNode(capture_field))), $(QuoteNode(v)))
            end
        end)
    end
    return Expr(:block, stmts...)
end

function _simos_store(mod, src, args)
    _ = mod
    _ = src
    return _simos_stage_mark_vars(args, "store", :blob_vars)
end

function _simos_hash(mod, src, args)
    _ = mod
    _ = src
    return _simos_stage_mark_vars(args, "hash", :hash_vars)
end

function _simos_inline(mod, src, args)
    _ = mod
    _ = src
    return _simos_stage_mark_vars(args, "inline", :inline_vars)
end

function _simos_meta(mod, src, args)
    stmts = Expr[]
    for p in args
        if p isa Expr && p.head == :(=)
            k = QuoteNode(p.args[1])
            v = p.args[2]
            push!(stmts, quote
                let sim = $(_SimKrn)._get_sim()
                    isnothing(sim.worksession) && error("No active session. Call `@simos session.init(...)` first.")
                    sim.worksession.capture_policy.meta_buffer[$k] = $v
                end
            end)
        else
            error("@simos meta expects key=value pairs, got: $p")
        end
    end
    return Expr(:block, stmts...)
end
