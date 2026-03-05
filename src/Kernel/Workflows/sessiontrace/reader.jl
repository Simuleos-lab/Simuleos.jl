# ============================================================
# sessiontrace/reader.jl — Project/session facade over sessiontrace readers
# ============================================================

function project(path::String)::SimuleosProject
    return resolve_project(path)
end

function _active_session_id_for_project(
        proj::SimuleosProject
    )::Base.UUID
    sim = _get_simos()
    ws = sim.worksession
    isnothing(ws) && error("No active session. Pass `session=...` explicitly.")
    active_project = sim_project(sim)
    if active_project.simuleos_dir != proj.simuleos_dir
        error("Active session belongs to a different project. Pass `session=...` explicitly.")
    end
    return ws.session_id
end

function _resolve_session_id(
        proj::SimuleosProject,
        session::Union{Symbol, Base.UUID, String}
    )::Base.UUID
    if session === :active
        return _active_session_id_for_project(proj)
    end
    return resolve_session_id(proj, session)
end

function _scope_tape(
        proj::SimuleosProject,
        session::Union{Symbol, Base.UUID, String}
    )::TapeIO
    session_id = _resolve_session_id(proj, session)
    return session_tape(proj, session_id)
end

function each_commits(
        proj::SimuleosProject;
        session::Union{Symbol, Base.UUID, String} = :active
    )::Vector{RecCaptureCommitV1}
    tape = _scope_tape(proj, session)
    return fetch_scope_commits(tape)
end

function _src_file_match(scope::SnapScopeV1, pattern::String)::Bool
    sf = get(scope.metadata, :src_file, nothing)
    isnothing(sf) && return false
    return endswith(string(sf), pattern)
end

function _scope_label_match(scope::SnapScopeV1, label::String)::Bool
    return any(==(label), scope.labels)
end

function each_scopes(
        proj::SimuleosProject;
        session::Union{Symbol, Base.UUID, String} = :active,
        commit_label::Union{String, Nothing} = nothing,
        src_file::Union{String, Nothing} = nothing,
        scope_label::Union{String, Nothing} = nothing,
    )::Vector{SnapScopeV1}
    tape = _scope_tape(proj, session)
    return fetch_scope_snapshots(
        tape;
        commit_filter = (commit, raw, ctx) -> isnothing(commit_label) || commit.label == commit_label,
        scope_filter = (scope, commit, raw, ctx, scope_ord) ->
            (isnothing(src_file) || _src_file_match(scope, src_file)) &&
            (isnothing(scope_label) || _scope_label_match(scope, scope_label)),
    )
end

"""
    latest_scope(proj::SimuleosProject; session=:active, commit_label=nothing, src_file=nothing, scope_label=nothing) -> SnapScopeV1

Return the latest scope in tape order for the resolved session,
optionally filtered by commit label and/or source file path.
"""
function latest_scope(
        proj::SimuleosProject;
        session::Union{Symbol, Base.UUID, String} = :active,
        commit_label::Union{String, Nothing} = nothing,
        src_file::Union{String, Nothing} = nothing,
        scope_label::Union{String, Nothing} = nothing,
    )
    tape = _scope_tape(proj, session)
    latest = latest_scope_snapshot(
        tape;
        commit_filter = (commit, raw, ctx) -> isnothing(commit_label) || commit.label == commit_label,
        scope_filter = (scope, commit, raw, ctx, scope_ord) ->
            (isnothing(src_file) || _src_file_match(scope, src_file)) &&
            (isnothing(scope_label) || _scope_label_match(scope, scope_label)),
    )

    isnothing(latest) && error("No scopes found for session `$(string(session))`" *
        (isnothing(commit_label) ? "" : ", commit_label=`$(commit_label)`") *
        (isnothing(src_file) ? "" : ", src_file=`$(src_file)`") *
        (isnothing(scope_label) ? "" : ", scope_label=`$(scope_label)`") *
        ".")
    return latest
end

value(var::ScopeVariable, proj::SimuleosProject) = scope_value(var, proj)
value(var::ScopeVariable, ::Nothing) = scope_value(var, nothing)
_scope_expand_level(var::ScopeVariable)::Symbol = scope_expand_level(var)

function _scope_expand_runtime!(
        scope::SnapScopeV1,
        proj,
        name::Symbol,
    )::Tuple{Symbol, Any}
    return scope_expand_runtime!(scope, proj, name)
end

_scope_expand_setglobal!(target_module::Module, name::Symbol, value) =
    scope_expand_setglobal!(target_module, name, value)

"""
    scope_table(proj::SimuleosProject; session=:active, commit_label=nothing, src_file=nothing, scope_label=nothing) -> Vector{Dict{Symbol, Any}}

Flatten scope data into tabular rows suitable for `DataFrame()`.
"""
function scope_table(
        proj::SimuleosProject;
        session::Union{Symbol, Base.UUID, String} = :active,
        commit_label::Union{String, Nothing} = nothing,
        src_file::Union{String, Nothing} = nothing,
        scope_label::Union{String, Nothing} = nothing,
    )::Vector{Dict{Symbol, Any}}
    tape = _scope_tape(proj, session)
    rows = table_scope_snapshots(
        tape;
        commit_filter = (commit, raw, ctx) -> isnothing(commit_label) || commit.label == commit_label,
        scope_filter = (scope, commit, raw, ctx, scope_ord) ->
            (isnothing(src_file) || _src_file_match(scope, src_file)) &&
            (isnothing(scope_label) || _scope_label_match(scope, scope_label)),
        row_builder = function (scope, commit, raw, ctx, scope_ord)
            row = Dict{Symbol, Any}()
            row[:commit_label] = commit.label
            row[:scope_labels] = join(scope.labels, ";")
            for (k, v) in scope.metadata
                row[k] = v
            end
            for (name, var) in scope.variables
                row[name] = value(var, proj)
            end
            return row
        end,
    )
    return Dict{Symbol, Any}[row for row in rows]
end
