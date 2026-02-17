# ==================================
# @session_init - Initialize session with metadata and directory structure
# I3x — expands to `session_init!(labels, src_file)` → uses `SIMOS[]`, writes `SIMOS[].worksession`
# ==================================
macro session_init(labels...)
    src_file = string(__source__.file)
    label_exprs = [l isa Union{String, Number, Bool} ? l : esc(l) for l in labels]
    quote
        $(_WorkSession).session_init_from_macro!(Any[$(label_exprs...)], $(src_file))
    end
end

# ==================================
# @session_store - Mark variables for blob storage (per-scope)
# I3x — via `_get_worksession()` and `_get_sim()` → writes `SIMOS[].worksession.stage.blob_refs`
# ==================================
macro session_store(vars...)
    symbols = Symbol[]
    for v in vars
        append!(symbols, _extract_symbols(v))
    end
    quote
        ws = $(_WorkSession)._get_worksession()
        _simos = $(_Kernel)._get_sim()
        _storage = $(_Kernel).sim_project(_simos).blobstorage
        $(
            [
                quote
                    if haskey(ws.stage.blob_refs, $(QuoteNode(sym)))
                        error("Variable $(string($(QuoteNode(sym)))) is already marked for blob storage in current capture.")
                    end
                    _value = $(esc(sym))
                    ws.stage.blob_refs[$(QuoteNode(sym))] = $(_Kernel).blob_write(
                        _storage,
                        _value,
                        _value
                    )
                end
                for sym in symbols
            ]...
        )
        nothing
    end |> esc
end

# ==================================
# @scope_context - Add context labels and data to current capture
# I3x — via `_get_worksession()` → reads/writes `SIMOS[].worksession.stage.current_scope`
# Usage: @scope_context "label"
#        @scope_context :key => value
#        @scope_context "label" :key1 => val1 :key2 => val2
# ==================================
macro scope_context(args...)
    exprs = []
    for arg in args
        if arg isa String
            # String literal label — goes on scope.labels
            push!(exprs, :(push!(ws.stage.current_scope.labels, $arg)))
        elseif arg isa Expr && arg.head == :string
            # Interpolated string label — goes on scope.labels
            push!(exprs, :(push!(ws.stage.current_scope.labels, $arg)))
        elseif arg isa Expr && arg.head == :call && arg.args[1] == :(=>)
            # Key => value pair — goes on capture data
            key = arg.args[2]
            val = arg.args[3]
            push!(exprs, :(ws.stage.current_scope.data[$key] = $val))
        end
    end
    quote
        ws = $(_WorkSession)._get_worksession()
        $(exprs...)
        nothing
    end |> esc
end

# ==================================
# @scope_capture - Snapshot local scope + globals
# I3x — via `_get_worksession()` → reads/writes `SIMOS[].worksession`
# ==================================
macro scope_capture(label)
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

        # Finalize current staged capture from captured variables
        $(_Kernel)._fill_scope!(
            ws.stage, _locals, _globals,
            $(src_file), $(src_line), $(esc(label));
            simignore_rules = ws.simignore_rules
        )

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
        cc = ws.stage.current_scope
        if !isempty(cc.labels) || !isempty(cc.data) || !isempty(ws.stage.blob_refs)
            error("Cannot commit: current capture has pending context (labels, data, or blob_refs). " *
                  "Use @scope_capture first to finalize the scope.")
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
    scope_capture(label::String, locals::Dict{Symbol, Any}, globals::Dict{Symbol, Any}, src_file::String, src_line::Int)

I3x — via `_get_worksession()` → reads/writes `SIMOS[].worksession`

Programmatic form of @scope_capture. Caller must provide locals/globals.
"""
function scope_capture(label::String, locals::Dict{Symbol, Any}, globals::Dict{Symbol, Any}, src_file::String, src_line::Int)
    ws = _get_worksession()

    captured = Kernel._fill_scope!(
        ws.stage, locals, globals,
        src_file, src_line, label;
        simignore_rules = ws.simignore_rules
    )

    return captured
end

"""
    session_commit(label::String="")

I3x — via `_get_worksession()`, `_get_sim()` → reads `SIMOS[].worksession`, `SIMOS[]`

Programmatic form of @session_commit. Persists stage and clears staged data.
"""
function session_commit(label::String="")
    ws = _get_worksession()
    simos = Kernel._get_sim()

    cc = ws.stage.current_scope
    if !isempty(cc.labels) || !isempty(cc.data) || !isempty(ws.stage.blob_refs)
        error("Cannot commit: current capture has pending context (labels, data, or blob_refs). " *
              "Use scope_capture first to finalize the scope.")
    end

    if !isempty(ws.stage.captures)
        _commit_worksession!(simos, ws, label)
    end

    return nothing
end
