# ------------------------------------------------------------------
# rec.jl — @simos rec.* handlers (recording write path)
#
# rec.blob, rec.hash, rec.inline, rec.meta — capture routing
# rec.capture — snapshot locals+globals into stage
# rec.commit, rec.queue — commit staged snapshots
# ------------------------------------------------------------------

# --- Capture routing ---

function _simos_rec_mark_vars(args, cmd::String, capture_field::Symbol)
    stmts = Expr[]
    for v in args
        v isa Symbol || error("@simos rec.$(cmd) expects variable names, got: $v")
        push!(stmts, quote
            let sim = $(_Krn)._get_simos()
                isnothing(sim.worksession) && error("No active session. Call `@simos session.init(...)` first.")
                push!(getfield(sim.worksession.capture_policy, $(QuoteNode(capture_field))), $(QuoteNode(v)))
            end
        end)
    end
    return Expr(:block, stmts...)
end

function _simos_rec_blob(mod, src, args)
    _ = mod; _ = src
    return _simos_rec_mark_vars(args, "blob", :blob_vars)
end

function _simos_rec_hash(mod, src, args)
    _ = mod; _ = src
    return _simos_rec_mark_vars(args, "hash", :hash_vars)
end

function _simos_rec_inline(mod, src, args)
    _ = mod; _ = src
    return _simos_rec_mark_vars(args, "inline", :inline_vars)
end

function _simos_rec_meta(mod, src, args)
    stmts = Expr[]
    for p in args
        if p isa Expr && p.head == :(=)
            k = QuoteNode(p.args[1])
            v = p.args[2]
            push!(stmts, quote
                let sim = $(_Krn)._get_simos()
                    isnothing(sim.worksession) && error("No active session. Call `@simos session.init(...)` first.")
                    sim.worksession.capture_policy.meta_buffer[$k] = $v
                end
            end)
        else
            error("@simos rec.meta expects key=value pairs, got: $p")
        end
    end
    return Expr(:block, stmts...)
end

# --- Capture ---

function _simos_rec_capture(mod, src, args)
    label_expr = isempty(args) ? "" : args[1]
    src_file = string(src.file)
    src_line = src.line
    return quote
        let
            _locals = Base.@locals
            _globals = Dict{Symbol, Any}()
            for name in names($mod; all=false)
                haskey(_locals, name) && continue
                isdefined($mod, name) || continue
                _globals[name] = getfield($mod, name)
            end

            $(_WS).scope_capture(
                string($label_expr),
                _locals,
                _globals,
                $src_file,
                $src_line,
            )
        end
    end
end

# --- Commit / Queue ---

function _simos_rec_commit(mod, src, args)
    label_expr = isempty(args) ? "" : args[1]
    return quote
        $(_WS).session_commit(string($label_expr))
    end
end

function _simos_rec_queue(mod, src, args, kwargs::Vector{Expr}=Expr[])
    label_expr = isempty(args) ? "" : args[1]
    if isempty(kwargs)
        return quote
            $(_WS).session_batch_commit(string($label_expr))
        end
    end
    return quote
        $(_WS).session_batch_commit(string($label_expr); $(kwargs...))
    end
end
