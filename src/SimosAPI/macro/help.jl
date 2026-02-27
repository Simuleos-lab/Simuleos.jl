# ------------------------------------------------------------------
# Dispatcher macro
# ------------------------------------------------------------------

"""
    @simos
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
$(_simos_command_help_rows_md())
"""
macro simos(invocation...)
    local result_expr
    local sgl_enabled
    sgl_enabled = nothing
    if isempty(invocation)
        result_expr = :($(_SimKrn).SIMOS[])
    elseif length(invocation) == 1 && invocation[1] === :help
        # @simos help — print full help overview
        help_str = _simos_help_text()
        result_expr = :(print($help_str))
    elseif length(invocation) == 1 && invocation[1] isa Expr &&
            (((invocation[1])::Expr).head === :call || ((invocation[1])::Expr).head === :do)
        path, posargs, kwargs, payload_expr = _simos_parse_invocation(invocation[1])
        # @simos <command>.help() — per-command help
        if !isempty(path) && last(path) === :help
            cmd_path = path[1:end-1]
            isempty(posargs) && isempty(kwargs) && isnothing(payload_expr) ||
                error("@simos $(_simos_path_str(path)) does not accept arguments.")
            help_str = _simos_command_help_text(Tuple(cmd_path))
            result_expr = :(print($help_str))
        else
            # Extract per-call `sgl` kwarg before dispatch
            sgl_enabled = _simos_extract_sgl_kwarg!(kwargs)
            result_expr = _simos_dispatch_call(__module__, __source__, path, posargs, kwargs, payload_expr)
        end
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
