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
    return Kernel.iterate_commits(tape)
end

function each_scopes(
        project_driver::Kernel.SimuleosProject;
        session::Union{Symbol, Base.UUID, String} = :active,
        commit_label::Union{String, Nothing} = nothing,
        src_file::Union{String, Nothing} = nothing,
    )
    commits = if isnothing(commit_label) && isnothing(src_file)
        each_commits(project_driver; session=session)
    else
        _each_commits_filtered(project_driver, session, commit_label, src_file)
    end
    return (
        scope
        for commit in commits
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

function _each_commits_filtered(
        project_driver::Kernel.SimuleosProject,
        session::Union{Symbol, Base.UUID, String},
        commit_label::Union{String, Nothing},
        src_file::Union{String, Nothing},
    )
    session_id = _resolve_session_id(project_driver, session)
    tape = Kernel.TapeIO(Kernel.tape_path(project_driver, session_id))

    function line_filter(line::AbstractString, ctx)
        !isnothing(commit_label) && !isempty(commit_label) && !occursin(commit_label, line) && return false
        !isnothing(src_file) && !isempty(src_file) && !occursin(src_file, line) && return false
        return true
    end

    function json_filter(raw::AbstractDict, ctx)
        get(raw, "type", "") == "commit" || return false
        if !isnothing(commit_label)
            string(get(raw, "commit_label", "")) == commit_label || return false
        end
        return true
    end

    raws = Kernel.each_tape_records_filtered(tape; line_filter=line_filter, json_filter=json_filter)
    return (Kernel._parse_commit(raw) for raw in raws)
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
value(var::Kernel.HashedScopeVariable, project_driver::Kernel.SimuleosProject) = nothing
value(var::Kernel.InlineScopeVariable, ::Nothing) = var.value
value(var::Kernel.VoidScopeVariable, ::Nothing) = nothing
value(var::Kernel.HashedScopeVariable, ::Nothing) = nothing
function value(var::Kernel.BlobScopeVariable, ::Nothing)
    error("Cannot resolve blob-backed scope variable `$(var.type_short)` without a project driver.")
end

_scope_expand_level(var::Kernel.InlineScopeVariable)::Symbol = var.level
_scope_expand_level(var::Kernel.BlobScopeVariable)::Symbol = var.level
_scope_expand_level(var::Kernel.VoidScopeVariable)::Symbol = var.level
_scope_expand_level(var::Kernel.HashedScopeVariable)::Symbol = var.level

function _scope_expand_runtime!(
        scope::Kernel.SimuleosScope,
        project_driver,
        name::Symbol
    )::Tuple{Symbol, Any}
    haskey(scope.variables, name) || error("Variable `$(name)` not found in scope.")
    var = scope.variables[name]
    return (_scope_expand_level(var), value(var, project_driver))
end

function _scope_expand_setglobal!(target_module::Module, name::Symbol, value)
    isdefined(target_module, name) || error(
        "Global `$(name)` is not defined in module `$(target_module)`. " *
        "Define it before calling @simos expand."
    )
    Core.setglobal!(target_module, name, value)
    return value
end


"""
    scope_table(project_driver; session=:active, commit_label=nothing, src_file=nothing) -> Vector{Dict{Symbol, Any}}

Flatten scope data into tabular rows suitable for `DataFrame()`.

Each row contains:
- `:commit_label` — the commit label string
- `:scope_labels` — semicolon-joined scope labels
- metadata keys (as-is)
- variable names with resolved values (inline, blob, or `nothing` for void)
"""
function scope_table(
        project_driver::Kernel.SimuleosProject;
        session::Union{Symbol, Base.UUID, String} = :active,
        commit_label::Union{String, Nothing} = nothing,
        src_file::Union{String, Nothing} = nothing,
    )::Vector{Dict{Symbol, Any}}
    rows = Dict{Symbol, Any}[]
    commits = if isnothing(commit_label) && isnothing(src_file)
        each_commits(project_driver; session=session)
    else
        _each_commits_filtered(project_driver, session, commit_label, src_file)
    end
    for commit in commits
        if !isnothing(commit_label) && commit.commit_label != commit_label
            continue
        end
        for scope in commit.scopes
            if !isnothing(src_file) && !_src_file_match(scope, src_file)
                continue
            end
            row = Dict{Symbol, Any}()
            row[:commit_label] = commit.commit_label
            row[:scope_labels] = join(scope.labels, ";")
            for (k, v) in scope.metadata
                row[k] = v
            end
            for (name, var) in scope.variables
                row[name] = value(var, project_driver)
            end
            push!(rows, row)
        end
    end
    return rows
end

end # module ScopeReader
