# ============================================================
# ScopeReader.jl — Project-driven query API
# ============================================================
module ScopeReader

import ..Kernel
const _SR = ScopeReader

function project(path::String)::Kernel.SimuleosProject
    return Kernel.resolve_project(path)
end

function _active_session_id_for_project(
        project_driver::Kernel.SimuleosProject
    )::Base.UUID
    sim = Kernel._get_sim()
    ws = sim.worksession
    isnothing(ws) && error("No active session. Pass `session=...` explicitly.")
    active_project = Kernel.sim_project(sim)
    if active_project.simuleos_dir != project_driver.simuleos_dir
        error("Active session belongs to a different project. Pass `session=...` explicitly.")
    end
    return ws.session_id
end

function _resolve_session_id(
        project_driver::Kernel.SimuleosProject,
        session::Union{Symbol, Base.UUID, String}
    )::Base.UUID
    if session === :active
        return _active_session_id_for_project(project_driver)
    end
    return Kernel.resolve_session_id(project_driver, session)
end

function each_commits(
        project_driver::Kernel.SimuleosProject;
        session::Union{Symbol, Base.UUID, String} = :active
    )
    session_id = _resolve_session_id(project_driver, session)
    tape = Kernel.TapeIO(Kernel.tape_path(project_driver, session_id))
    return Kernel.iterate_tape(tape)
end

function each_scopes(
        project_driver::Kernel.SimuleosProject;
        session::Union{Symbol, Base.UUID, String} = :active,
        commit_label::Union{String, Nothing} = nothing,
        src_file::Union{String, Nothing} = nothing,
    )
    return (
        scope
        for commit in each_commits(project_driver; session=session)
        if isnothing(commit_label) || commit.commit_label == commit_label
        for scope in commit.scopes
        if isnothing(src_file) || _src_file_match(scope, src_file)
    )
end

function _src_file_match(scope::Kernel.SimuleosScope, pattern::String)::Bool
    sf = get(scope.metadata, :src_file, nothing)
    isnothing(sf) && return false
    return endswith(string(sf), pattern)
end

"""
    latest_scope(project_driver; session=:active, commit_label=nothing, src_file=nothing) -> SimuleosScope

Return the last scope available for the resolved session,
optionally filtered by commit label and/or source file path.

- `commit_label`: only consider scopes from commits with this label.
- `src_file`: only consider scopes whose `src_file` metadata ends with this string.
"""
function latest_scope(
        project_driver::Kernel.SimuleosProject;
        session::Union{Symbol, Base.UUID, String} = :active,
        commit_label::Union{String, Nothing} = nothing,
        src_file::Union{String, Nothing} = nothing,
    )
    latest = nothing
    for scope in each_scopes(project_driver; session=session, commit_label=commit_label, src_file=src_file)
        latest = scope
    end
    isnothing(latest) && error("No scopes found for session `$(string(session))`" *
        (isnothing(commit_label) ? "" : ", commit_label=`$(commit_label)`") *
        (isnothing(src_file) ? "" : ", src_file=`$(src_file)`") *
        ".")
    return latest
end

value(var::Kernel.InlineScopeVariable, project_driver::Kernel.SimuleosProject) = var.value
value(var::Kernel.BlobScopeVariable, project_driver::Kernel.SimuleosProject) = Kernel.blob_read(project_driver.blobstorage, var.blob_ref)
value(var::Kernel.VoidScopeVariable, project_driver::Kernel.SimuleosProject) = nothing

_scope_expand_level(var::Kernel.InlineScopeVariable)::Symbol = var.level
_scope_expand_level(var::Kernel.BlobScopeVariable)::Symbol = var.level
_scope_expand_level(var::Kernel.VoidScopeVariable)::Symbol = var.level

function _scope_expand_runtime!(
        scope::Kernel.SimuleosScope,
        project_driver::Kernel.SimuleosProject,
        name::Symbol
    )::Tuple{Symbol, Any}
    haskey(scope.variables, name) || error("Variable `$(name)` not found in scope.")
    var = scope.variables[name]
    return (_scope_expand_level(var), value(var, project_driver))
end

function _scope_expand_setglobal!(target_module::Module, name::Symbol, value)
    isdefined(target_module, name) || error(
        "Global `$(name)` is not defined in module `$(target_module)`. " *
        "Define it before calling @scope_expand."
    )
    Core.setglobal!(target_module, name, value)
    return value
end

"""
    @scope_expand(scope, project, vars...)

Hydrate selected variables from a recorded scope into the caller context.

- Variables recorded as `:local` are assigned in the caller scope.
- Variables recorded as `:global` are assigned into the caller module globals.
  The target global binding must already exist.
"""
macro scope_expand(scope_expr, project_expr, vars...)
    isempty(vars) && error("@scope_expand expects at least one variable name.")

    for v in vars
        v isa Symbol || error("@scope_expand expects variable names, got: $v")
    end

    scope_in = esc(scope_expr)
    project_in = esc(project_expr)
    caller_module = QuoteNode(__module__)

    stmts = Expr[]
    for v in vars
        name = QuoteNode(v)
        level_sym = gensym(:scope_expand_level)
        value_sym = gensym(:scope_expand_value)
        push!(stmts, quote
            local $level_sym, $value_sym
            $level_sym, $value_sym = $(_SR)._scope_expand_runtime!($scope_in, $project_in, $name)
            if $level_sym === :global
                $(_SR)._scope_expand_setglobal!($caller_module, $name, $value_sym)
            elseif $level_sym === :local
                $(esc(v)) = $value_sym
            else
                error("Unsupported scope level `$($level_sym)` for variable `$(string($name))`.")
            end
        end)
    end

    return Expr(:block, stmts...)
end

end # module ScopeReader
