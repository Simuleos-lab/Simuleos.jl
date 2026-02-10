# Macro implementations for Simuleos Recorder

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

# Module references for use in macro-generated code
const _Recorder = Recorder
const _Core = Core

# ==================================
# @session_init - Initialize session with metadata and directory structure
# ==================================
macro session_init(label)
    src_file = string(__source__.file)
    quote
        $(_Recorder).session_init($(esc(label)), $(src_file))
    end
end

# ==================================
# @session_store - Mark variables for blob storage (per-scope)
# ==================================
macro session_store(vars...)
    symbols = Symbol[]
    for v in vars
        append!(symbols, _extract_symbols(v))
    end
    quote
        r = $(_Recorder)._get_recorder()
        $(
            [
                :(push!(r.stage.current_scope.blob_set, $(QuoteNode(sym))))
                for sym in symbols
            ]...
        )
        nothing
    end |> esc
end

# ==================================
# @session_context - Add context labels and data to current scope
# Usage: @session_context "label"
#        @session_context :key => value
#        @session_context "label" :key1 => val1 :key2 => val2
# ==================================
macro session_context(args...)
    exprs = []
    for arg in args
        if arg isa String
            # String literal label
            push!(exprs, :(push!(r.stage.current_scope.labels, $arg)))
        elseif arg isa Expr && arg.head == :string
            # Interpolated string label
            push!(exprs, :(push!(r.stage.current_scope.labels, $(esc(arg)))))
        elseif arg isa Expr && arg.head == :call && arg.args[1] == :(=>)
            # Key => value pair
            key = arg.args[2]
            val = arg.args[3]
            push!(exprs, :(r.stage.current_scope.data[$(QuoteNode(key))] = $(esc(val))))
        end
    end
    quote
        r = $(_Recorder)._get_recorder()
        $(exprs...)
        nothing
    end |> esc
end

# ==================================
# @session_capture - Snapshot local scope + globals
# ==================================
macro session_capture(label)
    src_file = string(__source__.file)
    src_line = __source__.line
    quote
        r = $(_Recorder)._get_recorder()
        _simos = $(_Core)._get_sim()

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

        # Finalize current_scope with captured variables
        $(_Recorder)._fill_scope!(
            r.stage.current_scope, r.stage, _locals, _globals,
            $(src_file), $(src_line), $(esc(label));
            simignore_rules = r.simignore_rules,
            simos = _simos
        )

        # Push finalized scope to stage.scopes
        push!(r.stage.scopes, r.stage.current_scope)

        # Create new current_scope for next capture
        r.stage.current_scope = $(_Core).Scope()

        r.stage.scopes[end]
    end
end

# ==================================
# @session_commit - Persist stage to JSONL tape (optional label), clears recorder
# ==================================
macro session_commit(label="")
    quote
        r = $(_Recorder)._get_recorder()
        _simos = $(_Core)._get_sim()

        # Check for pending context in current_scope
        cs = r.stage.current_scope
        if !isempty(cs.labels) || !isempty(cs.data) || !isempty(cs.blob_set)
            error("Cannot commit: current_scope has pending context (labels, data, or blob_set). " *
                  "Use @session_capture first to finalize the scope.")
        end

        if !isempty(r.stage.scopes)
            $(_Recorder).write_commit_to_tape(
                r.label, $(esc(label)), r.stage, r.meta;
                simos = _simos
            )
            r.stage = $(_Core).Stage()
        end

        # Clear recorder on SIMOS
        _simos.recorder = nothing

        nothing
    end
end

# ==================================
# Function forms (dual API)
# ==================================

"""
    session_capture(label::String, locals::Dict{Symbol, Any}, globals::Dict{Symbol, Any}, src_file::String, src_line::Int)

Programmatic form of @session_capture. Caller must provide locals/globals.
"""
function session_capture(label::String, locals::Dict{Symbol, Any}, globals::Dict{Symbol, Any}, src_file::String, src_line::Int)
    r = _get_recorder()
    simos = Core._get_sim()

    _fill_scope!(
        r.stage.current_scope, r.stage, locals, globals,
        src_file, src_line, label;
        simignore_rules = r.simignore_rules,
        simos = simos
    )

    push!(r.stage.scopes, r.stage.current_scope)
    r.stage.current_scope = Core.Scope()
    return r.stage.scopes[end]
end

"""
    session_commit(label::String="")

Programmatic form of @session_commit. Persists stage and clears recorder.
"""
function session_commit(label::String="")
    r = _get_recorder()
    simos = Core._get_sim()

    cs = r.stage.current_scope
    if !isempty(cs.labels) || !isempty(cs.data) || !isempty(cs.blob_set)
        error("Cannot commit: current_scope has pending context (labels, data, or blob_set). " *
              "Use session_capture first to finalize the scope.")
    end

    if !isempty(r.stage.scopes)
        write_commit_to_tape(r.label, label, r.stage, r.meta; simos = simos)
        r.stage = Core.Stage()
    end

    # Clear recorder
    simos.recorder = nothing
    return nothing
end
