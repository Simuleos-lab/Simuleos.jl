# Macro implementations for Simuleos

using Dates

# Helper to extract symbols from macro arguments
function _extract_symbols(expr)
    if expr isa Symbol
        return [expr]
    elseif expr isa Expr && expr.head == :tuple
        return [arg for arg in expr.args if arg isa Symbol]
    else
        return Symbol[]
    end
end

# Helper function to process scope from locals and globals
function _process_scope(
    session::Session,
    locals::Dict{Symbol, Any},
    globals::Dict{Symbol, Any},
    label::String
)::Scope
    variables = Dict{String, ScopeVariable}()
    ctx = session.current_context

    # Helper to process a single variable
    function process_var!(sym::Symbol, val::Any, src::Symbol)
        name = string(sym)
        type_str = string(typeof(val))

        if sym in ctx.blob_set
            hash = _write_blob(session, val)
            push!(session.stage.blob_refs, hash)
            variables[name] = ScopeVariable(
                name = name, type = type_str,
                value = nothing, blob_ref = hash, src = src
            )
        elseif _is_lite(val)
            variables[name] = ScopeVariable(
                name = name, type = type_str,
                value = _liteify(val), blob_ref = nothing, src = src
            )
        else
            variables[name] = ScopeVariable(
                name = name, type = type_str,
                value = nothing, blob_ref = nothing, src = src
            )
        end
    end

    # Process globals first (can be overridden by locals)
    for (sym, val) in globals
        process_var!(sym, val, :global)
    end

    # Process locals (override globals if same name)
    for (sym, val) in locals
        process_var!(sym, val, :local)
    end

    # Create scope with context
    return Scope(label, now(), variables, copy(ctx.labels), copy(ctx.data))
end

# ============================================================================
# @sim_session - Initialize session with metadata and directory structure
# ============================================================================
macro sim_session(label)
    src_file = string(__source__.file)
    src_dir = dirname(src_file)
    quote
        Simuleos._reset_session!()
        root = joinpath($(src_dir), ".simuleos")

        # Create session-specific directory
        safe_label = replace($(esc(label)), r"[^\w\-]" => "_")
        session_dir = joinpath(root, "sessions", safe_label)
        mkpath(joinpath(session_dir, "tapes"))
        mkpath(joinpath(root, "blobs"))  # Global blobs

        meta = Simuleos._capture_metadata($(src_file))
        global Simuleos.__SIM_SESSION__ = Simuleos.Session(
            label = $(esc(label)),
            root_dir = root,
            stage = Simuleos.Stage(Simuleos.Scope[], Set{String}()),
            meta = meta,
            current_context = Simuleos.ScopeContext()
        )
    end
end

# ============================================================================
# @sim_store - Mark variables for blob storage (per-scope)
# ============================================================================
macro sim_store(vars...)
    symbols = Symbol[]
    for v in vars
        append!(symbols, _extract_symbols(v))
    end
    exprs = [:(push!(s.current_context.blob_set, $(QuoteNode(sym)))) for sym in symbols]
    quote
        s = Simuleos._get_session()
        $(exprs...)
        nothing
    end |> esc
end

# ============================================================================
# @sim_context - Add context labels and data to current scope
# Usage: @sim_context "label"
#        @sim_context :key => value
#        @sim_context "label" :key1 => val1 :key2 => val2
# ============================================================================
macro sim_context(args...)
    exprs = []
    for arg in args
        if arg isa String
            # String literal label
            push!(exprs, :(push!(s.current_context.labels, $arg)))
        elseif arg isa Expr && arg.head == :string
            # Interpolated string label
            push!(exprs, :(push!(s.current_context.labels, $(esc(arg)))))
        elseif arg isa Expr && arg.head == :call && arg.args[1] == :(=>)
            # Key => value pair
            key = arg.args[2]
            val = arg.args[3]
            push!(exprs, :(s.current_context.data[$(QuoteNode(key))] = $(esc(val))))
        end
    end
    quote
        s = Simuleos._get_session()
        $(exprs...)
        nothing
    end |> esc
end

# ============================================================================
# @sim_capture - Snapshot local scope + globals
# ============================================================================
macro sim_capture(label)
    quote
        s = Simuleos._get_session()

        # Capture locals
        _locals = Base.@locals()

        # Capture globals from Main (filter modules/functions)
        _global_names = names(Main; imported = false)
        _globals = Dict{Symbol, Any}()
        for name in _global_names
            if isdefined(Main, name)
                val = getfield(Main, name)
                # Filter out modules and functions - capture only data
                if !(val isa Module || val isa Function)
                    # Check simignore patterns (stub for now)
                    Simuleos._should_ignore(s, name, val) && continue
                    _globals[name] = val
                end
            end
        end

        # Process scope with locals, globals, and current context
        scope = Simuleos._process_scope(s, _locals, _globals, $(esc(label)))
        push!(s.stage.scopes, scope)

        # Reset context for next scope
        s.current_context = Simuleos.ScopeContext()
        scope
    end
end

# ============================================================================
# @sim_commit - Persist stage to JSONL tape (optional label)
# ============================================================================
macro sim_commit(label="")
    quote
        s = Simuleos._get_session()
        if !isempty(s.stage.scopes)
            commit_label = $(esc(label))
            record = Simuleos._create_commit_record(s, commit_label)
            Simuleos._append_to_tape(s, record)
            s.stage = Simuleos.Stage(Simuleos.Scope[], Set{String}())
        end
        nothing
    end
end
