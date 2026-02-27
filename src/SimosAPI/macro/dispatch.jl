function _simos_guard_no_posargs(path, posargs::Vector{Any}, error_msg = nothing)
    isempty(posargs) && return nothing
    if isnothing(error_msg)
        error("@simos $(_simos_path_str(path)) accepts no positional arguments.")
    end
    error(String(error_msg))
end

function _simos_guard_posargs_exactly(path, posargs::Vector{Any}, expected::Int, error_msg = nothing)
    length(posargs) == expected && return nothing
    if isnothing(error_msg)
        error("@simos $(_simos_path_str(path)) expects exactly $(expected) positional arguments.")
    end
    error(String(error_msg))
end

function _simos_command_spec(path::Tuple, description::AbstractString, handler::Function;
        invoke_mode::Symbol,
        require_no_kwargs::Bool = false,
        require_no_do::Bool = false,
        posargs_rule::Symbol = :any,
        posargs_count::Int = 0,
        posargs_error = nothing,
        validator = nothing,
    )
    posargs_rule in (:any, :none, :exactly) ||
        error("@simos internal error: unsupported posargs_rule `$(posargs_rule)` for `$(_simos_path_str(path))`.")

    return (
        path = path,
        description = String(description),
        handler = handler,
        invoke_mode = invoke_mode,
        require_no_kwargs = require_no_kwargs,
        require_no_do = require_no_do,
        posargs_rule = posargs_rule,
        posargs_count = posargs_count,
        posargs_error = isnothing(posargs_error) ? nothing : String(posargs_error),
        validator = validator,
    )
end

function _simos_validate_cache_remember(path, posargs::Vector{Any}, kwargs::Vector{Expr}, payload_expr)
    _ = path
    _ = kwargs
    length(posargs) in (2, 3) ||
        error("@simos cache.remember expects `(ctx_hash, target)` plus a `do` block or explicit payload expression.")

    if !isnothing(payload_expr) && length(posargs) != 2
        error("@simos cache.remember do form expects exactly `(ctx_hash, target)` positional arguments.")
    end
    if isnothing(payload_expr) && length(posargs) == 2
        error("@simos cache.remember requires a `do` block or an explicit third payload expression.")
    end
    return nothing
end

function _simos_dispatch_cache_remember(mod, src, posargs::Vector{Any}, kwargs::Vector{Expr}, payload_expr)
    ctx_hash_expr = posargs[1]
    target_expr = posargs[2]
    payload = isnothing(payload_expr) ? posargs[3] : payload_expr

    args = Any[ctx_hash_expr]
    isempty(kwargs) || push!(args, _simos_kwargs_tuple_expr(kwargs))
    push!(args, Expr(:(=), target_expr, payload))
    return _simos_remember(mod, src, args)
end

const _SIMOS_COMMAND_SPECS = (
    _simos_command_spec((:system, :init), "Engine init/reinit (`bootstrap`, `sandbox`, `reinit`, `sandbox_cleanup`, `project_basename_hint`)", _simos_init;
        invoke_mode = :kw_assigns,
        require_no_do = true,
        posargs_rule = :none,
        posargs_error = "@simos system.init is engine-only and does not accept session labels. Use `@simos session.init(...)`.",
    ),
    _simos_command_spec((:system, :reset), "Reset engine state", _simos_reset;
        invoke_mode = :kw_assigns,
        require_no_do = true,
        posargs_rule = :none,
        posargs_error = "@simos system.reset accepts only keyword arguments.",
    ),
    _simos_command_spec((:project, :current), "Active `SimuleosProject`", _simos_project_current;
        invoke_mode = :mod_src,
        require_no_kwargs = true,
        require_no_do = true,
        posargs_rule = :none,
        posargs_error = "@simos project.current accepts no positional arguments.",
    ),
    _simos_command_spec((:settings, :get), "Read one setting (`default`, `layer`)", _simos_settings_get;
        invoke_mode = :mod_src_posargs_kwargs,
        require_no_do = true,
    ),
    _simos_command_spec((:settings, :has), "Check if a setting exists (`layer`)", _simos_settings_has;
        invoke_mode = :mod_src_posargs_kwargs,
        require_no_do = true,
    ),
    _simos_command_spec((:settings, :require), "Read one setting or error (`layer`)", _simos_settings_require;
        invoke_mode = :mod_src_posargs_kwargs,
        require_no_do = true,
    ),
    _simos_command_spec((:settings, :explain), "Explain resolved value/layer candidates", _simos_settings_explain;
        invoke_mode = :mod_src_posargs_kwargs,
        require_no_do = true,
    ),
    _simos_command_spec((:settings, :layers), "List active settings layers/sources", _simos_settings_layers;
        invoke_mode = :mod_src,
        require_no_kwargs = true,
        require_no_do = true,
        posargs_rule = :none,
        posargs_error = "@simos settings.layers accepts no positional arguments.",
    ),
    _simos_command_spec((:settings, :snapshot), "Snapshot settings dict (`layer`, `prefix`, `nested`)", _simos_settings_snapshot;
        invoke_mode = :mod_src_kwargs,
        require_no_do = true,
        posargs_rule = :none,
        posargs_error = "@simos settings.snapshot accepts no positional arguments.",
    ),
    _simos_command_spec((:settings, :set), "Set a key in a mutable layer (`layer`)", _simos_settings_set;
        invoke_mode = :mod_src_posargs_kwargs,
        require_no_do = true,
    ),
    _simos_command_spec((:settings, :unset), "Remove a key from a mutable layer (`layer`)", _simos_settings_unset;
        invoke_mode = :mod_src_posargs_kwargs,
        require_no_do = true,
    ),
    _simos_command_spec((:settings, :merge), "Merge a dict into a mutable layer (`layer`, `clear`)", _simos_settings_merge;
        invoke_mode = :mod_src_posargs_kwargs,
        require_no_do = true,
    ),
    _simos_command_spec((:settings, :clear), "Clear mutable layer keys (`layer`, `prefix`)", _simos_settings_clear;
        invoke_mode = :mod_src_kwargs,
        require_no_do = true,
        posargs_rule = :none,
        posargs_error = "@simos settings.clear accepts no positional arguments.",
    ),
    _simos_command_spec((:settings, :source, :add_json), "Add external JSON settings source", _simos_settings_source_add_json;
        invoke_mode = :mod_src_posargs_kwargs,
        require_no_do = true,
    ),
    _simos_command_spec((:settings, :source, :add_args), "Add CLI-args settings source", _simos_settings_source_add_args;
        invoke_mode = :mod_src_posargs_kwargs,
        require_no_do = true,
    ),
    _simos_command_spec((:settings, :source, :reload), "Reload one source or all reloadable sources", _simos_settings_source_reload;
        invoke_mode = :mod_src_posargs_kwargs,
        require_no_do = true,
    ),
    _simos_command_spec((:settings, :source, :remove), "Remove external settings source", _simos_settings_source_remove;
        invoke_mode = :mod_src_posargs,
        require_no_kwargs = true,
        require_no_do = true,
    ),
    _simos_command_spec((:settings, :source, :list), "List settings sources/layers", _simos_settings_source_list;
        invoke_mode = :mod_src,
        require_no_kwargs = true,
        require_no_do = true,
        posargs_rule = :none,
        posargs_error = "@simos settings.source.list accepts no positional arguments.",
    ),
    _simos_command_spec((:settings, :registry, :register), "Register a settings registry entry", _simos_settings_registry_register;
        invoke_mode = :mod_src_posargs_kwargs,
        require_no_do = true,
    ),
    _simos_command_spec((:settings, :registry, :unregister), "Remove a settings registry entry", _simos_settings_registry_unregister;
        invoke_mode = :mod_src_posargs,
        require_no_kwargs = true,
        require_no_do = true,
    ),
    _simos_command_spec((:settings, :registry, :list), "List settings registry entries", _simos_settings_registry_list;
        invoke_mode = :mod_src,
        require_no_kwargs = true,
        require_no_do = true,
        posargs_rule = :none,
        posargs_error = "@simos settings.registry.list accepts no positional arguments.",
    ),
    _simos_command_spec((:sqlite, :path), "SQLite metadata-index path for active project", _simos_sqlite_path;
        invoke_mode = :mod_src,
        require_no_kwargs = true,
        require_no_do = true,
        posargs_rule = :none,
        posargs_error = "@simos sqlite.path accepts no positional arguments.",
    ),
    _simos_command_spec((:sqlite, :open), "Open/cache SQLite metadata-index DB (`sync=:none|:refresh|:rebuild`)", _simos_sqlite_open;
        invoke_mode = :mod_src_kwargs,
        require_no_do = true,
        posargs_rule = :none,
        posargs_error = "@simos sqlite.open accepts only keyword arguments (e.g. `sync=:refresh`).",
    ),
    _simos_command_spec((:sqlite, :current), "Current cached SQLite DB handle", _simos_sqlite_current;
        invoke_mode = :mod_src,
        require_no_kwargs = true,
        require_no_do = true,
        posargs_rule = :none,
        posargs_error = "@simos sqlite.current accepts no positional arguments.",
    ),
    _simos_command_spec((:sqlite, :execute), "Execute SQL on cached SQLite DB", _simos_sqlite_execute;
        invoke_mode = :mod_src_posargs,
        require_no_kwargs = true,
        require_no_do = true,
    ),
    _simos_command_spec((:sqlite, :refresh), "Refresh metadata index (reopen cached DB if needed)", _simos_sqlite_refresh;
        invoke_mode = :mod_src,
        require_no_kwargs = true,
        require_no_do = true,
        posargs_rule = :none,
        posargs_error = "@simos sqlite.refresh accepts no positional arguments.",
    ),
    _simos_command_spec((:sqlite, :rebuild), "Rebuild metadata index (reopen cached DB if needed)", _simos_sqlite_rebuild;
        invoke_mode = :mod_src,
        require_no_kwargs = true,
        require_no_do = true,
        posargs_rule = :none,
        posargs_error = "@simos sqlite.rebuild accepts no positional arguments.",
    ),
    _simos_command_spec((:sqlite, :close), "Close cached SQLite DB handle", _simos_sqlite_close;
        invoke_mode = :mod_src,
        require_no_kwargs = true,
        require_no_do = true,
        posargs_rule = :none,
        posargs_error = "@simos sqlite.close accepts no positional arguments.",
    ),
    _simos_command_spec((:blob, :meta), "Latest metadata record for a blob", _simos_blob_meta;
        invoke_mode = :mod_src_posargs,
        require_no_kwargs = true,
        require_no_do = true,
    ),
    _simos_command_spec((:session, :init), "Initialize a work session", _simos_session_init;
        invoke_mode = :mod_src_posargs,
        require_no_kwargs = true,
        require_no_do = true,
    ),
    _simos_command_spec((:session, :commit), "Commit staged scopes", _simos_commit;
        invoke_mode = :mod_src_posargs,
        require_no_kwargs = true,
        require_no_do = true,
    ),
    _simos_command_spec((:session, :queue), "Queue a batch commit", _simos_batch_commit;
        invoke_mode = :mod_src_posargs_kwargs,
        require_no_do = true,
    ),
    _simos_command_spec((:session, :close), "Finalize and flush session", _simos_finalize;
        invoke_mode = :mod_src_posargs,
        require_no_kwargs = true,
        require_no_do = true,
    ),
    _simos_command_spec((:stage, :blob), "Mark variables for blob storage", _simos_store;
        invoke_mode = :mod_src_posargs,
        require_no_kwargs = true,
        require_no_do = true,
    ),
    _simos_command_spec((:stage, :hash), "Mark variables for hash-only storage", _simos_hash;
        invoke_mode = :mod_src_posargs,
        require_no_kwargs = true,
        require_no_do = true,
    ),
    _simos_command_spec((:stage, :inline), "Mark variables for inline storage", _simos_inline;
        invoke_mode = :mod_src_posargs,
        require_no_kwargs = true,
        require_no_do = true,
    ),
    _simos_command_spec((:stage, :meta), "Set stage metadata key-value pairs", _simos_meta;
        invoke_mode = :kw_assigns,
        require_no_do = true,
        posargs_rule = :none,
        posargs_error = "@simos stage.meta accepts only keyword arguments.",
    ),
    _simos_command_spec((:scope, :capture), "Capture local/global variables", _simos_capture;
        invoke_mode = :mod_src_posargs,
        require_no_kwargs = true,
        require_no_do = true,
    ),
    _simos_command_spec((:scope, :bind), "Bind scope variables into caller", _simos_expand;
        invoke_mode = :mod_src_posargs,
        require_no_kwargs = true,
        require_no_do = true,
    ),
    _simos_command_spec((:shared, :capture), "Capture vars into in-memory shared scope", _simos_shared_capture;
        invoke_mode = :mod_src_posargs,
        require_no_kwargs = true,
        require_no_do = true,
    ),
    _simos_command_spec((:shared, :bind), "Bind vars from in-memory shared scope", _simos_shared_bind;
        invoke_mode = :mod_src_posargs,
        require_no_kwargs = true,
        require_no_do = true,
    ),
    _simos_command_spec((:shared, :merge), "Merge shared scope variables (shallow overwrite)", _simos_shared_merge;
        invoke_mode = :mod_src_posargs,
        require_no_kwargs = true,
        require_no_do = true,
    ),
    _simos_command_spec((:shared, :keys), "List shared scope keys", _simos_shared_keys;
        invoke_mode = :mod_src_posargs,
        require_no_kwargs = true,
        require_no_do = true,
    ),
    _simos_command_spec((:shared, :has), "Check if shared scope key exists", _simos_shared_has;
        invoke_mode = :mod_src_posargs,
        require_no_kwargs = true,
        require_no_do = true,
    ),
    _simos_command_spec((:shared, :drop), "Delete one shared scope key", _simos_shared_drop;
        invoke_mode = :mod_src_posargs,
        require_no_kwargs = true,
        require_no_do = true,
    ),
    _simos_command_spec((:shared, :clear), "Clear shared scope registry", _simos_shared_clear;
        invoke_mode = :mod_src_posargs,
        require_no_kwargs = true,
        require_no_do = true,
    ),
    _simos_command_spec((:cache, :key), "Compute a named context hash", _simos_ctx_hash;
        invoke_mode = :posargs_plus_kw_assigns,
        require_no_do = true,
    ),
    _simos_command_spec((:cache, :remember), "Cache-or-compute with context hash", _simos_remember;
        invoke_mode = :cache_remember,
        validator = _simos_validate_cache_remember,
    ),
    _simos_command_spec((:settings, :tracking, :on), "Enable settings access tracking for current session", _simos_settings_tracking_on;
        invoke_mode = :mod_src,
        require_no_kwargs = true,
        require_no_do = true,
        posargs_rule = :none,
        posargs_error = "@simos settings.tracking.on accepts no positional arguments.",
    ),
    _simos_command_spec((:settings, :tracking, :off), "Disable settings access tracking for current session", _simos_settings_tracking_off;
        invoke_mode = :mod_src,
        require_no_kwargs = true,
        require_no_do = true,
        posargs_rule = :none,
        posargs_error = "@simos settings.tracking.off accepts no positional arguments.",
    ),
    _simos_command_spec((:context, :capture), "Capture effective session context", _simos_context_capture;
        invoke_mode = :mod_src,
        require_no_kwargs = true,
        require_no_do = true,
        posargs_rule = :none,
        posargs_error = "@simos context.capture accepts no positional arguments.",
    ),
    _simos_command_spec((:context, :resolve), "Resolve context payload by ref/hash", _simos_context_resolve;
        invoke_mode = :mod_src_posargs,
        require_no_kwargs = true,
        require_no_do = true,
        posargs_rule = :exactly,
        posargs_count = 1,
        posargs_error = "@simos context.resolve expects exactly one argument (RecordRef or hash string).",
    ),
)

const _SIMOS_COMMANDS = Tuple(spec.path for spec in _SIMOS_COMMAND_SPECS)
const _SIMOS_COMMAND_SPECS_BY_PATH = Dict(spec.path => spec for spec in _SIMOS_COMMAND_SPECS)

length(_SIMOS_COMMAND_SPECS_BY_PATH) == length(_SIMOS_COMMAND_SPECS) ||
    error("@simos internal error: duplicate command path in command spec table.")

function _simos_command_list_str()
    return join((_simos_path_str(cmd) for cmd in _SIMOS_COMMANDS), ", ")
end

function _simos_command_help_rows_md()
    return join(
        ("| `$(_simos_path_str(spec.path))` | $(spec.description) |" for spec in _SIMOS_COMMAND_SPECS),
        "\n",
    )
end

# ------------------------------------------------------------------
# Help text generation (compile-time, embedded as string literals)
# ------------------------------------------------------------------

function _simos_group_specs()
    groups = Dict{String, Vector{@NamedTuple{path::String, description::String}}}()
    for spec in _SIMOS_COMMAND_SPECS
        group = string(spec.path[1])
        entry = (path = _simos_path_str(spec.path), description = spec.description)
        push!(get!(Vector{@NamedTuple{path::String, description::String}}, groups, group), entry)
    end
    return groups
end

function _simos_help_text()::String
    groups = _simos_group_specs()
    group_order = unique(string(spec.path[1]) for spec in _SIMOS_COMMAND_SPECS)

    io = IOBuffer()
    println(io, "@simos — Unified dispatch macro for Simuleos")
    println(io, "")
    println(io, "Usage:  @simos <group>.<command>(<args>...)")
    println(io, "        @simos help              — this overview")
    println(io, "        @simos <command>.help()   — help for a specific command")
    println(io, "")
    for group in group_order
        entries = groups[group]
        println(io, "  ", group)
        maxpath = maximum(length(e.path) for e in entries)
        for e in entries
            println(io, "    ", rpad(e.path, maxpath), "  ", e.description)
        end
        println(io)
    end
    return String(take!(io))
end

function _simos_command_help_text(cmd_path::Tuple)::String
    spec = get(_SIMOS_COMMAND_SPECS_BY_PATH, cmd_path, nothing)
    isnothing(spec) &&
        return "Unknown command `$(_simos_path_str(cmd_path))`. Run `@simos help` for a list of commands."

    io = IOBuffer()
    path_str = _simos_path_str(spec.path)
    println(io, "@simos ", path_str)
    println(io, "")
    println(io, "  ", spec.description)
    println(io, "")

    # Positional arguments hint
    if spec.posargs_rule === :none
        println(io, "  Positional args : none")
    elseif spec.posargs_rule === :exactly
        println(io, "  Positional args : exactly ", spec.posargs_count)
    else
        println(io, "  Positional args : any")
    end

    # Keyword arguments hint
    if spec.require_no_kwargs
        println(io, "  Keyword args    : none")
    else
        println(io, "  Keyword args    : yes")
    end

    # Do block hint
    if spec.require_no_do
        println(io, "  Do block        : no")
    else
        println(io, "  Do block        : yes")
    end

    println(io)
    return String(take!(io))
end

function _simos_apply_command_guards!(spec, path::Tuple, posargs::Vector{Any}, kwargs::Vector{Expr}, payload_expr)
    spec.require_no_kwargs && _simos_disallow_kwargs(path, kwargs)
    spec.require_no_do && _simos_disallow_do(path, payload_expr)

    if spec.posargs_rule === :none
        _simos_guard_no_posargs(path, posargs, spec.posargs_error)
    elseif spec.posargs_rule === :exactly
        _simos_guard_posargs_exactly(path, posargs, spec.posargs_count, spec.posargs_error)
    end

    validator = spec.validator
    isnothing(validator) || validator(path, posargs, kwargs, payload_expr)
    return nothing
end

function _simos_invoke_command(spec, mod, src, path::Tuple, posargs::Vector{Any}, kwargs::Vector{Expr}, payload_expr)
    handler = spec.handler
    mode = spec.invoke_mode

    if mode === :mod_src
        return handler(mod, src)
    elseif mode === :mod_src_posargs
        return handler(mod, src, posargs)
    elseif mode === :mod_src_kwargs
        return handler(mod, src, kwargs)
    elseif mode === :mod_src_posargs_kwargs
        return handler(mod, src, posargs, kwargs)
    elseif mode === :kw_assigns
        args = Any[_simos_kw_to_assign.(kwargs)...]
        return handler(mod, src, args)
    elseif mode === :posargs_plus_kw_assigns
        args = Any[posargs...]
        append!(args, _simos_kw_to_assign.(kwargs))
        return handler(mod, src, args)
    elseif mode === :cache_remember
        return _simos_dispatch_cache_remember(mod, src, posargs, kwargs, payload_expr)
    end

    error("@simos internal error: unsupported invoke mode `$(mode)` for `$(_simos_path_str(path))`.")
end

function _simos_dispatch_call(mod, src, path::Tuple, posargs::Vector{Any}, kwargs::Vector{Expr}, payload_expr)
    spec = get(_SIMOS_COMMAND_SPECS_BY_PATH, path, nothing)
    isnothing(spec) &&
        error("Unknown @simos command `$(_simos_path_str(path))`. Valid commands: $(_simos_command_list_str())")

    _simos_apply_command_guards!(spec, path, posargs, kwargs, payload_expr)
    return _simos_invoke_command(spec, mod, src, path, posargs, kwargs, payload_expr)
end
