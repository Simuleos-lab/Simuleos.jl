# ------------------------------------------------------------------
# SQLite index runtime helpers (used by @simos sqlite.* handlers)
# ------------------------------------------------------------------

function _simos_sqlite_sync_mode(sync)::Symbol
    if sync isa Symbol
        mode = sync
    elseif sync isa AbstractString
        mode = Symbol(String(sync))
    else
        error("@simos sqlite.open `sync` must be Symbol/String (:none, :refresh, :rebuild), got $(typeof(sync)).")
    end
    mode in (:none, :refresh, :rebuild) ||
        error("@simos sqlite.open unknown `sync=$(repr(mode))`. Valid options: :none, :refresh, :rebuild.")
    return mode
end

function _simos_sqlite_require_sim_project()
    sim = _SimKrn._get_sim()
    proj = _SimKrn.sim_project(sim)
    return sim, proj
end

function _simos_sqlite_expected_path(sim, proj)::String
    _ = sim
    return _SimSQLI.sqlite_index_path(proj)
end

function _simos_sqlite_close_cached_if_any!(sim)::Bool
    return _SimKrn._simos_close_cached_sqlite_db!(sim)
end

function _simos_sqlite_assert_cached_matches_project!(sim, proj)
    isnothing(sim.sqlite_db) && return nothing
    expected_path = _simos_sqlite_expected_path(sim, proj)
    if isnothing(sim.sqlite_db_path)
        sim.sqlite_db_path = expected_path
        return nothing
    end
    if abspath(String(sim.sqlite_db_path)) != abspath(expected_path)
        _simos_sqlite_close_cached_if_any!(sim)
        error("Cached SQLite DB belongs to a different active project. Call `@simos sqlite.open(...)`.")
    end
    return nothing
end

function _simos_sqlite_current_runtime()
    sim, proj = _simos_sqlite_require_sim_project()
    _simos_sqlite_assert_cached_matches_project!(sim, proj)
    isnothing(sim.sqlite_db) && error("No open SQLite metadata-index connection. Call `@simos sqlite.open(...)` first.")
    return sim.sqlite_db
end

function _simos_sqlite_path_runtime()
    sim, proj = _simos_sqlite_require_sim_project()
    return _simos_sqlite_expected_path(sim, proj)
end

function _simos_sqlite_open_runtime!(; sync = :refresh)
    sim, proj = _simos_sqlite_require_sim_project()
    mode = _simos_sqlite_sync_mode(sync)

    _simos_sqlite_assert_cached_matches_project!(sim, proj)

    if mode === :none && !isnothing(sim.sqlite_db)
        return sim.sqlite_db
    end

    if !isnothing(sim.sqlite_db)
        _simos_sqlite_close_cached_if_any!(sim)
    end

    if mode === :refresh
        _SimSQLI.sqlite_index_refresh!(proj)
    elseif mode === :rebuild
        _SimSQLI.sqlite_index_rebuild!(proj)
    elseif mode === :none
        # no-op
    else
        error("Unhandled sqlite sync mode: $(mode)")
    end

    db = _SimSQLI.sqlite_index_open(proj)
    sim.sqlite_db = db
    sim.sqlite_db_path = _simos_sqlite_expected_path(sim, proj)
    return db
end

function _simos_sqlite_refresh_runtime!()
    sim, proj = _simos_sqlite_require_sim_project()
    _simos_sqlite_assert_cached_matches_project!(sim, proj)
    reopen = !isnothing(sim.sqlite_db)
    reopen && _simos_sqlite_close_cached_if_any!(sim)
    path = _SimSQLI.sqlite_index_refresh!(proj)
    if reopen
        sim.sqlite_db = _SimSQLI.sqlite_index_open(proj)
        sim.sqlite_db_path = _simos_sqlite_expected_path(sim, proj)
    end
    return path
end

function _simos_sqlite_rebuild_runtime!()
    sim, proj = _simos_sqlite_require_sim_project()
    _simos_sqlite_assert_cached_matches_project!(sim, proj)
    reopen = !isnothing(sim.sqlite_db)
    reopen && _simos_sqlite_close_cached_if_any!(sim)
    path = _SimSQLI.sqlite_index_rebuild!(proj)
    if reopen
        sim.sqlite_db = _SimSQLI.sqlite_index_open(proj)
        sim.sqlite_db_path = _simos_sqlite_expected_path(sim, proj)
    end
    return path
end

function _simos_sqlite_close_runtime!()
    sim = _SimKrn._get_sim()
    return _simos_sqlite_close_cached_if_any!(sim)
end

_simos_sqlite_execute_runtime(sql::AbstractString) =
    _SQLite.DBInterface.execute(_simos_sqlite_current_runtime(), String(sql))
_simos_sqlite_execute_runtime(sql::AbstractString, params) =
    _SQLite.DBInterface.execute(_simos_sqlite_current_runtime(), String(sql), params)

# ------------------------------------------------------------------
# Settings runtime helpers (used by @simos settings.* handlers)
# ------------------------------------------------------------------

function _simos_settings_layer_symbol(layer)::Symbol
    if layer isa Symbol
        return layer
    elseif layer isa AbstractString
        s = strip(String(layer))
        isempty(s) && error("@simos settings layer cannot be empty.")
        return Symbol(s)
    else
        error("@simos settings layer must be a Symbol/String, got $(typeof(layer)).")
    end
end

function _simos_settings_get_runtime(key_in; default=nothing, layer=:effective)
    sim = _SimKrn._get_sim()
    key = string(key_in)
    layer_sym = _simos_settings_layer_symbol(layer)
    if layer_sym === :effective
        return _SimKrn.get_setting(sim, key, default)
    end
    ex = _SimKrn.settings_explain(sim, key; layer = layer_sym)
    return ex.found ? ex.value : default
end

function _simos_settings_explain_runtime(key_in; layer=:effective)
    sim = _SimKrn._get_sim()
    return _SimKrn.settings_explain(sim, string(key_in); layer = _simos_settings_layer_symbol(layer))
end

function _simos_settings_layers_runtime()
    sim = _SimKrn._get_sim()
    return _SimKrn.settings_source_list(sim)
end

function _simos_settings_has_runtime(key_in; layer=:effective)::Bool
    ex = _simos_settings_explain_runtime(key_in; layer = layer)
    return ex.found === true
end

function _simos_settings_require_runtime(key_in; layer=:effective)
    sim = _SimKrn._get_sim()
    key = string(key_in)
    layer_sym = _simos_settings_layer_symbol(layer)
    if layer_sym === :effective
        return _SimKrn.settings(sim, key)
    end
    ex = _SimKrn.settings_explain(sim, key; layer = layer_sym)
    ex.found && return ex.value
    error("Missing setting: $(key) (layer=$(layer_sym))")
end

function _simos_settings_snapshot_runtime(; layer=:effective, prefix="", nested::Bool=false)
    sim = _SimKrn._get_sim()
    stack = _SimKrn._settings_stack_required(sim)
    layer_sym = _simos_settings_layer_symbol(layer)

    flat = if layer_sym === :effective
        _SimKrn._settings_stack_snapshot(stack)
    else
        layer_obj = _SimKrn._settings_stack_layer(stack, layer_sym)
        isnothing(layer_obj) && error("Unknown settings layer: $(layer_sym)")
        copy(layer_obj.data)
    end

    prefix_s = isnothing(prefix) ? "" : String(prefix)
    if !isempty(prefix_s)
        filtered = Dict{String, Any}()
        for (k, v) in flat
            startswith(k, prefix_s) || continue
            filtered[k] = v
        end
        flat = filtered
    end

    return nested ? _SimKrn._settings_unflatten_dict(flat) : flat
end

function _simos_settings_set_runtime(key_in, value; layer=:script)
    sim = _SimKrn._get_sim()
    _SimKrn.settings_layer_set!(sim, _simos_settings_layer_symbol(layer), string(key_in), value)
    return nothing
end

function _simos_settings_unset_runtime(key_in; layer=:script)
    sim = _SimKrn._get_sim()
    return _SimKrn.settings_layer_unset!(sim, _simos_settings_layer_symbol(layer), string(key_in))
end

function _simos_settings_merge_runtime(data; layer=:script, clear::Bool=false)
    sim = _SimKrn._get_sim()
    data isa AbstractDict || error("@simos settings.merge expects an AbstractDict payload.")
    return _SimKrn.settings_layer_merge!(sim, _simos_settings_layer_symbol(layer), data; clear = clear)
end

function _simos_settings_clear_runtime(; layer=:script, prefix=nothing)
    sim = _SimKrn._get_sim()
    return _SimKrn.settings_layer_clear!(sim, _simos_settings_layer_symbol(layer); prefix = prefix)
end

function _simos_settings_source_name_symbol(name)::Symbol
    if name isa Symbol
        return name
    elseif name isa AbstractString
        s = strip(String(name))
        isempty(s) && error("@simos settings source name cannot be empty.")
        return Symbol(s)
    else
        error("@simos settings source name must be a Symbol/String, got $(typeof(name)).")
    end
end

function _simos_settings_source_add_args_runtime(args; after=:env)
    sim = _SimKrn._get_sim()
    args isa AbstractVector || error("@simos settings.source.add_args expects a Vector{String} argument.")
    args_str = String[string(a) for a in args]
    after_sym = _simos_settings_layer_symbol(after)
    return _SimKrn.settings_source_add_args!(sim, args_str; after=after_sym)
end

function _simos_settings_source_list_runtime()
    return _simos_settings_layers_runtime()
end

function _simos_settings_source_add_json_runtime(
        path_in;
        name=nothing,
        after=:project,
        optional::Bool=false,
        replace::Bool=false,
    )
    sim = _SimKrn._get_sim()
    name_norm = isnothing(name) ? nothing : _simos_settings_source_name_symbol(name)
    after_norm = _simos_settings_layer_symbol(after)
    return _SimKrn.settings_source_add_json!(
        sim,
        string(path_in);
        name = name_norm,
        after = after_norm,
        optional = optional,
        replace = replace,
    )
end

function _simos_settings_source_remove_runtime(name_in)
    sim = _SimKrn._get_sim()
    _SimKrn.settings_source_remove!(sim, _simos_settings_source_name_symbol(name_in))
    return nothing
end

function _simos_settings_source_reload_runtime()
    sim = _SimKrn._get_sim()
    return _SimKrn.settings_reload!(sim)
end

function _simos_settings_source_reload_runtime(name_in)
    sim = _SimKrn._get_sim()
    return _SimKrn.settings_source_reload!(sim, _simos_settings_source_name_symbol(name_in))
end

function _simos_context_capture_runtime!()
    sim = _SimKrn._get_sim()
    ws = sim.worksession
    isnothing(ws) && error("No active session. Call `@simos session.init(...)` first.")
    proj = _SimKrn.sim_project(sim)
    return _SimWS.context_capture!(ws, proj)
end

function _simos_context_resolve_runtime(ref_input)
    sim = _SimKrn._get_sim()
    ws = sim.worksession
    isnothing(ws) && error("No active session. Call `@simos session.init(...)` first.")
    proj = _SimKrn.sim_project(sim)
    ref_str = if ref_input isa _SimKrn.RecordRef
        ref_input.hash
    else
        string(ref_input)
    end
    return _SimWS.context_resolve(proj, ws, ref_str)
end

function _simos_context_capture(mod, src)
    _ = mod; _ = src
    return quote
        $(_SimosAPI)._simos_context_capture_runtime!()
    end
end

function _simos_context_resolve(mod, src, args)
    _ = mod; _ = src
    ref_expr = args[1]
    return quote
        $(_SimosAPI)._simos_context_resolve_runtime($(ref_expr))
    end
end

function _simos_settings_tracking_toggle_runtime!(on::Bool)::Bool
    sim = _SimKrn._get_sim()
    ws = sim.worksession
    isnothing(ws) && error("No active session. Call `@simos session.init(...)` first.")
    ws.settings_access_tracking = on
    if on && isnothing(ws.settings_access_log)
        ws.settings_access_log = Dict{String, Any}()
    end
    return on
end

function _simos_settings_tracking_on(mod, src)
    _ = mod; _ = src
    return quote
        $(_SimosAPI)._simos_settings_tracking_toggle_runtime!(true)
    end
end

function _simos_settings_tracking_off(mod, src)
    _ = mod; _ = src
    return quote
        $(_SimosAPI)._simos_settings_tracking_toggle_runtime!(false)
    end
end
