# ==================================
# @session_init - Initialize session with metadata and directory structure
# I3x — expands to `session_init(label, src_file)` → uses `SIMOS[]`, writes `SIMOS[].worksession`
# ==================================
macro session_init(label)
    src_file = string(__source__.file)
    quote
        $(_WorkSession).session_init($(esc(label)), $(src_file))
    end
end

# ==================================
# @session_store - Mark variables for blob storage (per-scope)
# I3x — via `_get_worksession()` → reads `SIMOS[].worksession.stage.current.blob_set`
# ==================================
macro session_store(vars...)
    symbols = Symbol[]
    for v in vars
        append!(symbols, _extract_symbols(v))
    end
    quote
        ws = $(_WorkSession)._get_worksession()
        $(
            [
                :(push!(ws.stage.current.blob_set, $(QuoteNode(sym))))
                for sym in symbols
            ]...
        )
        nothing
    end |> esc
end

# ==================================
# @session_context - Add context labels and data to current capture
# I3x — via `_get_worksession()` → reads/writes `SIMOS[].worksession.stage.current`
# Usage: @session_context "label"
#        @session_context :key => value
#        @session_context "label" :key1 => val1 :key2 => val2
# ==================================
macro session_context(args...)
    exprs = []
    for arg in args
        if arg isa String
            # String literal label — goes on scope.labels
            push!(exprs, :(push!(ws.stage.current.scope.labels, $arg)))
        elseif arg isa Expr && arg.head == :string
            # Interpolated string label — goes on scope.labels
            push!(exprs, :(push!(ws.stage.current.scope.labels, $(esc(arg)))))
        elseif arg isa Expr && arg.head == :call && arg.args[1] == :(=>)
            # Key => value pair — goes on capture data
            key = arg.args[2]
            val = arg.args[3]
            push!(exprs, :(ws.stage.current.data[$(QuoteNode(key))] = $(esc(val))))
        end
    end
    quote
        ws = $(_WorkSession)._get_worksession()
        $(exprs...)
        nothing
    end |> esc
end

# ==================================
# @session_capture - Snapshot local scope + globals
# I3x — via `_get_worksession()` → reads/writes `SIMOS[].worksession`
# ==================================
macro session_capture(label)
    src_file = string(__source__.file)
    src_line = __source__.line
    quote
        ws = $(_WorkSession)._get_worksession()

        # Capture locals
        _locals = Base.@locals()

        # Capture globals from Main (filtering done in _fill_scope!)
        _global_names = names(Main; imported = false)
        _globals = Dict{Symbol, Any}()
        for name in _global_names
            if isdefined(Main, name)
                _globals[name] = getfield(Main, name)
            end
        end

        # Fill CaptureContext from captured variables
        $(_Kernel)._fill_scope!(
            ws.stage.current, _locals, _globals,
            $(src_file), $(src_line), $(esc(label));
            simignore_rules = ws.simignore_rules
        )

        # Push finalized capture to stage.captures
        push!(ws.stage.captures, ws.stage.current)

        # Create new CaptureContext for next capture
        ws.stage.current = $(_Kernel).CaptureContext()

        ws.stage.captures[end]
    end
end

# ==================================
# @session_commit - Persist stage to JSONL tape (optional label), clears staged data
# I3x — via `_get_worksession()`, `_get_sim()` → reads `SIMOS[].worksession`, `SIMOS[]`; writes tape
# ==================================
macro session_commit(label="")
    quote
        ws = $(_WorkSession)._get_worksession()
        _simos = $(_Kernel)._get_sim()

        # Check for pending context in current capture
        cc = ws.stage.current
        if !isempty(cc.scope.labels) || !isempty(cc.data) || !isempty(cc.blob_set)
            error("Cannot commit: current capture has pending context (labels, data, or blob_set). " *
                  "Use @session_capture first to finalize the scope.")
        end

        if !isempty(ws.stage.captures)
            $(_WorkSession)._commit_worksession!(_simos, ws, $(esc(label)))
        end

        nothing
    end
end

# ==================================
# Function forms (dual API)
# ==================================

"""
    session_capture(label::String, locals::Dict{Symbol, Any}, globals::Dict{Symbol, Any}, src_file::String, src_line::Int)

I3x — via `_get_worksession()` → reads/writes `SIMOS[].worksession`

Programmatic form of @session_capture. Caller must provide locals/globals.
"""
function session_capture(label::String, locals::Dict{Symbol, Any}, globals::Dict{Symbol, Any}, src_file::String, src_line::Int)
    ws = _get_worksession()

    Kernel._fill_scope!(
        ws.stage.current, locals, globals,
        src_file, src_line, label;
        simignore_rules = ws.simignore_rules
    )

    push!(ws.stage.captures, ws.stage.current)
    ws.stage.current = Kernel.CaptureContext()
    return ws.stage.captures[end]
end

"""
    session_commit(label::String="")

I3x — via `_get_worksession()`, `_get_sim()` → reads `SIMOS[].worksession`, `SIMOS[]`

Programmatic form of @session_commit. Persists stage and clears staged data.
"""
function session_commit(label::String="")
    ws = _get_worksession()
    simos = Kernel._get_sim()

    cc = ws.stage.current
    if !isempty(cc.scope.labels) || !isempty(cc.data) || !isempty(cc.blob_set)
        error("Cannot commit: current capture has pending context (labels, data, or blob_set). " *
              "Use session_capture first to finalize the scope.")
    end

    if !isempty(ws.stage.captures)
        _commit_worksession!(simos, ws, label)
    end

    return nothing
end
