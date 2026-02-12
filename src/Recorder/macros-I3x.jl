# ==================================
# @session_init - Initialize session with metadata and directory structure
# I3x — expands to `session_init(label, src_file)` → uses `SIMOS[]`, writes `SIMOS[].recorder`
# ==================================
macro session_init(label)
    src_file = string(__source__.file)
    quote
        $(_Recorder).session_init($(esc(label)), $(src_file))
    end
end

# ==================================
# @session_store - Mark variables for blob storage (per-scope)
# I3x — via `_get_recorder()` → reads `SIMOS[].recorder.stage.current.blob_set`
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
                :(push!(r.stage.current.blob_set, $(QuoteNode(sym))))
                for sym in symbols
            ]...
        )
        nothing
    end |> esc
end

# ==================================
# @session_context - Add context labels and data to current capture
# I3x — via `_get_recorder()` → reads/writes `SIMOS[].recorder.stage.current`
# Usage: @session_context "label"
#        @session_context :key => value
#        @session_context "label" :key1 => val1 :key2 => val2
# ==================================
macro session_context(args...)
    exprs = []
    for arg in args
        if arg isa String
            # String literal label — goes on scope.labels
            push!(exprs, :(push!(r.stage.current.scope.labels, $arg)))
        elseif arg isa Expr && arg.head == :string
            # Interpolated string label — goes on scope.labels
            push!(exprs, :(push!(r.stage.current.scope.labels, $(esc(arg)))))
        elseif arg isa Expr && arg.head == :call && arg.args[1] == :(=>)
            # Key => value pair — goes on capture data
            key = arg.args[2]
            val = arg.args[3]
            push!(exprs, :(r.stage.current.data[$(QuoteNode(key))] = $(esc(val))))
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
# I3x — via `_get_recorder()`, `_get_sim()` → reads `SIMOS[].recorder`, `SIMOS[]`
# ==================================
macro session_capture(label)
    src_file = string(__source__.file)
    src_line = __source__.line
    quote
        r = $(_Recorder)._get_recorder()
        _simos = $(_Kernel)._get_sim()

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
        $(_Recorder)._fill_scope!(
            _simos,
            r.stage.current, _locals, _globals,
            $(src_file), $(src_line), $(esc(label));
            simignore_rules = r.simignore_rules
        )

        # Push finalized capture to stage.captures
        push!(r.stage.captures, r.stage.current)

        # Create new CaptureContext for next capture
        r.stage.current = $(_Kernel).CaptureContext()

        r.stage.captures[end]
    end
end

# ==================================
# @session_commit - Persist stage to JSONL tape (optional label), clears recorder
# I3x — via `_get_recorder()`, `_get_sim()` → reads `SIMOS[].recorder`, `SIMOS[]`; writes tape, clears `SIMOS[].recorder`
# ==================================
macro session_commit(label="")
    quote
        r = $(_Recorder)._get_recorder()
        _simos = $(_Kernel)._get_sim()

        # Check for pending context in current capture
        cc = r.stage.current
        if !isempty(cc.scope.labels) || !isempty(cc.data) || !isempty(cc.blob_set)
            error("Cannot commit: current capture has pending context (labels, data, or blob_set). " *
                  "Use @session_capture first to finalize the scope.")
        end

        if !isempty(r.stage.captures)
            $(_Recorder).write_commit_to_tape(
                _simos,
                r.label, $(esc(label)), r.stage, r.meta
            )
            r.stage = $(_Kernel).Stage()
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

I3x — via `_get_recorder()`, `_get_sim()` → reads `SIMOS[].recorder`, `SIMOS[]`

Programmatic form of @session_capture. Caller must provide locals/globals.
"""
function session_capture(label::String, locals::Dict{Symbol, Any}, globals::Dict{Symbol, Any}, src_file::String, src_line::Int)
    r = _get_recorder()
    simos = Kernel._get_sim()

    _fill_scope!(
        simos,
        r.stage.current, locals, globals,
        src_file, src_line, label;
        simignore_rules = r.simignore_rules
    )

    push!(r.stage.captures, r.stage.current)
    r.stage.current = Kernel.CaptureContext()
    return r.stage.captures[end]
end

"""
    session_commit(label::String="")

I3x — via `_get_recorder()`, `_get_sim()` → reads `SIMOS[].recorder`, `SIMOS[]`; clears `SIMOS[].recorder`

Programmatic form of @session_commit. Persists stage and clears recorder.
"""
function session_commit(label::String="")
    r = _get_recorder()
    simos = Kernel._get_sim()

    cc = r.stage.current
    if !isempty(cc.scope.labels) || !isempty(cc.data) || !isempty(cc.blob_set)
        error("Cannot commit: current capture has pending context (labels, data, or blob_set). " *
              "Use session_capture first to finalize the scope.")
    end

    if !isempty(r.stage.captures)
        write_commit_to_tape(simos, r.label, label, r.stage, r.meta)
        r.stage = Kernel.Stage()
    end

    # Clear recorder
    simos.recorder = nothing
    return nothing
end
