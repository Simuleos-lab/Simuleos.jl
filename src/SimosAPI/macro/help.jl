const _SIMOS_COMMANDS = (
    (:system, :init),
    (:system, :reset),
    (:project, :current),
    (:settings, :get),
    (:settings, :has),
    (:settings, :require),
    (:settings, :explain),
    (:settings, :layers),
    (:settings, :snapshot),
    (:settings, :set),
    (:settings, :unset),
    (:settings, :merge),
    (:settings, :clear),
    (:settings, :source, :add_json),
    (:settings, :source, :add_args),
    (:settings, :source, :reload),
    (:settings, :source, :remove),
    (:settings, :source, :list),
    (:settings, :registry, :register),
    (:settings, :registry, :unregister),
    (:settings, :registry, :list),
    (:sqlite, :path),
    (:sqlite, :open),
    (:sqlite, :current),
    (:sqlite, :execute),
    (:sqlite, :refresh),
    (:sqlite, :rebuild),
    (:sqlite, :close),
    (:blob, :meta),
    (:session, :init),
    (:session, :commit),
    (:session, :queue),
    (:session, :close),
    (:stage, :blob),
    (:stage, :hash),
    (:stage, :inline),
    (:stage, :meta),
    (:scope, :capture),
    (:scope, :bind),
    (:shared, :capture),
    (:shared, :bind),
    (:shared, :merge),
    (:shared, :keys),
    (:shared, :has),
    (:shared, :drop),
    (:shared, :clear),
    (:cache, :key),
    (:cache, :remember),
    (:settings, :tracking, :on),
    (:settings, :tracking, :off),
    (:context, :capture),
    (:context, :resolve),
)

function _simos_command_list_str()
    return join((_simos_path_str(cmd) for cmd in _SIMOS_COMMANDS), ", ")
end


# ------------------------------------------------------------------
# Dispatcher macro
# ------------------------------------------------------------------

"""
    @simos system.init(...)
    @simos system.reset(...)
    @simos group.command(...)
    @simos cache.remember(...) do
        ...
    end

Unified dispatch macro for Simuleos. Uses a dotted command path plus normal
call syntax so the command path is clearly separated from the arguments.

## Commands

| Command | Description |
|---|---|
| `system.init` | Engine init/reinit |
| `system.reset` | Reset engine state |
| `project.current` | Active `SimuleosProject` |
| `settings.get` | Read one setting (`default`, `layer`) |
| `settings.has` | Check if a setting exists (`layer`) |
| `settings.require` | Read one setting or error (`layer`) |
| `settings.explain` | Explain resolved value/layer candidates |
| `settings.layers` | List active settings layers/sources |
| `settings.snapshot` | Snapshot settings dict (`layer`, `prefix`, `nested`) |
| `settings.set` | Set a key in a mutable layer (`layer`) |
| `settings.unset` | Remove a key from a mutable layer (`layer`) |
| `settings.merge` | Merge a dict into a mutable layer (`layer`, `clear`) |
| `settings.clear` | Clear mutable layer keys (`layer`, `prefix`) |
| `settings.source.add_json` | Add external JSON settings source |
| `settings.source.reload` | Reload one source or all reloadable sources |
| `settings.source.remove` | Remove external settings source |
| `settings.source.list` | List settings sources/layers |
| `settings.registry.register` | Register a settings registry entry |
| `settings.registry.unregister` | Remove a settings registry entry |
| `settings.registry.list` | List settings registry entries |
| `sqlite.path` | SQLite metadata-index path for active project |
| `sqlite.open` | Open/cache SQLite metadata-index DB (`sync=:none|:refresh|:rebuild`) |
| `sqlite.current` | Current cached SQLite DB handle |
| `sqlite.execute` | Execute SQL on cached SQLite DB |
| `sqlite.refresh` | Refresh metadata index (reopen cached DB if needed) |
| `sqlite.rebuild` | Rebuild metadata index (reopen cached DB if needed) |
| `sqlite.close` | Close cached SQLite DB handle |
| `blob.meta` | Latest metadata record for a blob |
| `session.init` | Initialize a work session |
| `session.commit` | Commit staged scopes |
| `session.queue` | Queue a batch commit |
| `session.close` | Finalize and flush session |
| `stage.blob` | Mark variables for blob storage |
| `stage.hash` | Mark variables for hash-only storage |
| `stage.inline` | Mark variables for inline storage |
| `stage.meta` | Set stage metadata key-value pairs |
| `scope.capture` | Capture local/global variables |
| `scope.bind` | Bind scope variables into caller |
| `shared.capture` | Capture vars into in-memory shared scope |
| `shared.bind` | Bind vars from in-memory shared scope |
| `shared.merge` | Merge shared scope variables (shallow overwrite) |
| `shared.keys` | List shared scope keys |
| `shared.has` | Check if shared scope key exists |
| `shared.drop` | Delete one shared scope key |
| `shared.clear` | Clear shared scope registry |
| `cache.key` | Compute a named context hash |
| `cache.remember` | Cache-or-compute with context hash |
"""
macro simos(invocation...)
    local result_expr
    if length(invocation) == 1 && invocation[1] isa Expr &&
            (((invocation[1])::Expr).head === :call || ((invocation[1])::Expr).head === :do)
        path, posargs, kwargs, payload_expr = _simos_parse_invocation(invocation[1])
        # Extract per-call `sgl` kwarg before dispatch
        sgl_enabled = _simos_extract_sgl_kwarg!(kwargs)
        result_expr = _simos_dispatch_call(__module__, __source__, path, posargs, kwargs, payload_expr)
    else
        error("@simos expects call-style syntax like `@simos system.command(args...; kwargs...)`. Valid commands: $(_simos_command_list_str())")
    end
    # SGL: serialize all @simos operations under SIMOS_GLOBAL_LOCK
    if sgl_enabled === true
        # sgl=true: always lock regardless of global flag
        locked_expr = quote
            @lock $(_SimosAPI).SIMOS_GLOBAL_LOCK begin
                $(result_expr)
            end
        end
    elseif sgl_enabled === false
        # sgl=false: never lock regardless of global flag
        locked_expr = result_expr
    else
        # no per-call override: defer to global flag
        locked_expr = quote
            if $(_SimosAPI).SIMOS_GLOBAL_LOCK_ENABLED[]
                @lock $(_SimosAPI).SIMOS_GLOBAL_LOCK begin
                    $(result_expr)
                end
            else
                $(result_expr)
            end
        end
    end
    return esc(locked_expr)
end
