# Macro implementations for Simuleos

using Dates

# Helper function to process scope from local variables
function _process_scope(session::Session, locals::Dict{Symbol, Any}, label::String)::Scope
    variables = Dict{String, ScopeVariable}()

    for (sym, val) in locals
        name = string(sym)
        type_str = string(typeof(val))

        if sym in session.blob_set
            # Store as blob
            hash = _write_blob(session, val)
            push!(session.stage.blob_refs, hash)
            variables[name] = ScopeVariable(
                name = name,
                type = type_str,
                value = nothing,
                blob_ref = hash
            )
        elseif _is_lite(val)
            # Store inline as lite value
            variables[name] = ScopeVariable(
                name = name,
                type = type_str,
                value = _liteify(val),
                blob_ref = nothing
            )
        else
            # Non-lite, not marked for blob - just record type
            variables[name] = ScopeVariable(
                name = name,
                type = type_str,
                value = nothing,
                blob_ref = nothing
            )
        end
    end

    return Scope(label, now(), variables)
end

macro sim_session(label)
    # Capture source info at macro expansion time
    src_file = string(__source__.file)
    src_dir = dirname(src_file)
    quote
        Simuleos._reset_session!()
        root = joinpath($(src_dir), ".simuleos")
        mkpath(joinpath(root, "blobs"))
        meta = Simuleos._capture_metadata($(src_file))
        global Simuleos.__SIM_SESSION__ = Simuleos.Session(
            label = $(esc(label)),
            root_dir = root,
            stage = Simuleos.Stage(Simuleos.Scope[], Set{String}()),
            meta = meta,
            blob_set = Set{Symbol}()
        )
    end
end

function _extract_symbols(expr)
    if expr isa Symbol
        return [expr]
    elseif expr isa Expr && expr.head == :tuple
        return [arg for arg in expr.args if arg isa Symbol]
    else
        return Symbol[]
    end
end

macro sim_store(vars...)
    # Handle both @sim_store(X, Y, Z) and @sim_store X, Y, Z
    symbols = Symbol[]
    for v in vars
        append!(symbols, _extract_symbols(v))
    end
    exprs = [:(push!(s.blob_set, $(QuoteNode(sym)))) for sym in symbols]
    quote
        s = Simuleos._get_session()
        $(exprs...)
        nothing
    end |> esc
end

macro sim_capture(label)
    quote
        s = Simuleos._get_session()
        _locals = Base.@locals()
        scope = Simuleos._process_scope(s, _locals, $(esc(label)))
        push!(s.stage.scopes, scope)
        empty!(s.blob_set)
        scope
    end
end

macro sim_commit()
    quote
        s = Simuleos._get_session()
        if !isempty(s.stage.scopes)
            record = Simuleos._create_commit_record(s)
            Simuleos._append_to_tape(s, record)
            s.stage = Simuleos.Stage(Simuleos.Scope[], Set{String}())
        end
        nothing
    end
end
