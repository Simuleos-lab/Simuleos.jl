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
# Mutates scope in-place, populating variables
function _process_scope!(
    scope::Scope,
    session::Session,
    locals::Dict{Symbol, Any},
    globals::Dict{Symbol, Any},
    label::String,
    src_file::String,
    src_line::Int
)
    # Helper to process a single variable
    function process_var!(sym::Symbol, val::Any, src::Symbol)
        name = string(sym)
        src_type = first(string(typeof(val)), 25)  # truncate to 25 chars

        if sym in scope.blob_set
            hash = _write_blob(session, val)
            scope.variables[name] = ScopeVariable(
                name = name, src_type = src_type,
                value = nothing, blob_ref = hash, src = src
            )
        elseif _is_lite(val)
            scope.variables[name] = ScopeVariable(
                name = name, src_type = src_type,
                value = _liteify(val), blob_ref = nothing, src = src
            )
        else
            scope.variables[name] = ScopeVariable(
                name = name, src_type = src_type,
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

    # Set scope metadata
    scope.label = label
    scope.timestamp = now()
    scope.isopen = false
    scope.data[:src_file] = src_file
    scope.data[:src_line] = src_line
    scope.data[:threadid] = Threads.threadid()

    return scope
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

        # Compute session directory path (created on-demand at write time)
        safe_label = replace($(esc(label)), r"[^\w\-]" => "_")
        session_dir = joinpath(root, "sessions", safe_label)

        meta = Simuleos._capture_metadata($(src_file))
        global Simuleos.__SIM_SESSION__ = Simuleos.Session(
            label = $(esc(label)),
            root_dir = root,
            stage = Simuleos.Stage(),
            meta = meta
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
    exprs = [:(push!(s.stage.current_scope.blob_set, $(QuoteNode(sym)))) for sym in symbols]
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
            push!(exprs, :(push!(s.stage.current_scope.labels, $arg)))
        elseif arg isa Expr && arg.head == :string
            # Interpolated string label
            push!(exprs, :(push!(s.stage.current_scope.labels, $(esc(arg)))))
        elseif arg isa Expr && arg.head == :call && arg.args[1] == :(=>)
            # Key => value pair
            key = arg.args[2]
            val = arg.args[3]
            push!(exprs, :(s.stage.current_scope.data[$(QuoteNode(key))] = $(esc(val))))
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
    src_file = string(__source__.file)
    src_line = __source__.line
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

        # Finalize current_scope with captured variables
        Simuleos._process_scope!(
            s.stage.current_scope, s, _locals, _globals,
            $(esc(label)), $(src_file), $(src_line)
        )

        # Push finalized scope to stage.scopes
        push!(s.stage.scopes, s.stage.current_scope)

        # Create new current_scope for next capture
        s.stage.current_scope = Simuleos.Scope()

        s.stage.scopes[end]
    end
end

# ============================================================================
# @sim_commit - Persist stage to JSONL tape (optional label)
# ============================================================================
macro sim_commit(label="")
    quote
        s = Simuleos._get_session()

        # Check for pending context in current_scope
        cs = s.stage.current_scope
        if !isempty(cs.labels) || !isempty(cs.data) || !isempty(cs.blob_set)
            error("Cannot commit: current_scope has pending context (labels, data, or blob_set). " *
                  "Use @sim_capture first to finalize the scope.")
        end

        if !isempty(s.stage.scopes)
            Simuleos._append_to_tape(s, $(esc(label)))
            s.stage = Simuleos.Stage()
        end
        nothing
    end
end
