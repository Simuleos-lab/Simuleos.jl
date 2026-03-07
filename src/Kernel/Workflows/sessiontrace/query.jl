# ============================================================
# sessiontrace/query.jl — Unified query runtime for @simos query
# ============================================================

"""
    simos_query(; class, session, commit_label, scope_label, src_file, latest, limit, where) -> Vector

Unified query over all registered tapes. Built-in kwargs are pre-filters,
`where` is a JMESPath post-filter expression applied to raw record dicts.

When `class` is `nothing`, no class filtering is applied (all record types returned).
When `session` is specified, only tapes tagged with that session are scanned.

Returns decoded SimuleosDataClass objects (RecCaptureCommitV1 or SnapScopeV1).
"""
function simos_query(;
        class::Union{String, Nothing} = nothing,
        session::Union{String, Symbol, Nothing} = nothing,
        commit_label::Union{String, Nothing} = nothing,
        scope_label::Union{String, Nothing} = nothing,
        src_file::Union{String, Nothing} = nothing,
        latest::Bool = false,
        limit::Union{Int, Nothing} = nothing,
        where::Union{String, Nothing} = nothing,
    )

    proj = sim_project()
    isnothing(proj) && error("No active Simuleos project. Call `@simos system.init(...)` first.")

    # Ensure tape registry is populated
    tape_registry_ensure!(proj)

    # Determine query target class (nothing = no class filter)
    target = _query_target_class(class)

    # Resolve tapes to scan
    tapes = _query_resolve_tapes(proj, session)

    # Collect results
    results = Any[]
    for tape in tapes
        _query_scan_tape!(results, tape, target, commit_label, scope_label, src_file, where)
    end

    # Post-processing: latest and limit
    if latest
        return isempty(results) ? results : Any[results[end]]
    end
    if !isnothing(limit) && length(results) > limit
        return results[end-limit+1:end]
    end
    return results
end

# --- Tape resolution ---

function _query_resolve_tapes(
        proj::SimuleosProject,
        session::Nothing,
    )::Vector{TapeIO}
    # No session filter: return all registered tapes
    return tape_registry_tapes(proj.tape_registry)
end

function _query_resolve_tapes(
        proj::SimuleosProject,
        session::Symbol,
    )::Vector{TapeIO}
    if session === :active
        sim = _get_simos()
        ws = sim.worksession
        isnothing(ws) && error("No active session. Pass `session=...` explicitly.")
        return TapeIO[session_tape(proj, ws.session_id)]
    end
    error("Unknown session symbol `:$(session)`. Use `:active` or a session label string.")
end

function _query_resolve_tapes(
        proj::SimuleosProject,
        session::AbstractString,
    )::Vector{TapeIO}
    sid = resolve_session_id(proj, session)
    return TapeIO[session_tape(proj, sid)]
end

# --- Target class ---

@enum _QueryTarget _QT_ALL _QT_COMMIT _QT_SCOPE

function _query_target_class(class::Nothing)::_QueryTarget
    return _QT_ALL  # no class filter: scan all record types
end

function _query_target_class(class::AbstractString)::_QueryTarget
    class == "rec.capture_commit" && return _QT_COMMIT
    class == "snap.scope" && return _QT_SCOPE
    error("@simos query: unsupported class `$(class)`. Supported: \"rec.capture_commit\", \"snap.scope\".")
end

# --- Tape scanning ---

function _query_scan_tape!(
        results::Vector{Any},
        tape::TapeIO,
        target::_QueryTarget,
        commit_label::Union{String, Nothing},
        scope_label::Union{String, Nothing},
        src_file::Union{String, Nothing},
        where_expr::Union{String, Nothing},
    )
    # Parse JMESPath expression once
    jmes_ast = isnothing(where_expr) ? nothing : _parse_jmespath(where_expr)

    if target == _QT_COMMIT
        _query_scan_commits!(results, tape, commit_label, scope_label, src_file, jmes_ast)
    elseif target == _QT_SCOPE
        _query_scan_scopes!(results, tape, commit_label, scope_label, src_file, jmes_ast)
    else  # _QT_ALL — scan both commits and scopes
        _query_scan_commits!(results, tape, commit_label, scope_label, src_file, jmes_ast)
        _query_scan_scopes!(results, tape, commit_label, scope_label, src_file, jmes_ast)
    end
    return nothing
end

function _query_scan_commits!(
        results::Vector{Any},
        tape::TapeIO,
        commit_label::Union{String, Nothing},
        scope_label::Union{String, Nothing},
        src_file::Union{String, Nothing},
        jmes_ast::Union{JMESNode, Nothing},
    )
    each_scope_commits(
        tape;
        commit_filter = function (commit, raw, ctx)
            # Built-in pre-filters
            !isnothing(commit_label) && commit.label != commit_label && return false
            if !isnothing(scope_label) || !isnothing(src_file)
                scopes = commit_scope_snapshots(commit)
                any_match = any(scopes) do scope
                    (!isnothing(scope_label) && !any(==(scope_label), scope.labels)) && return false
                    (!isnothing(src_file) && !_src_file_match(scope, src_file)) && return false
                    return true
                end
                any_match || return false
            end
            return true
        end,
        on_commit = function (commit, raw, ctx)
            # JMESPath post-filter on raw dict
            if !isnothing(jmes_ast)
                _jmes_is_truthy(jmespath_eval(jmes_ast, raw)) || return nothing
            end
            push!(results, commit)
            return nothing
        end,
    )
    return nothing
end

function _query_scan_scopes!(
        results::Vector{Any},
        tape::TapeIO,
        commit_label::Union{String, Nothing},
        scope_label::Union{String, Nothing},
        src_file::Union{String, Nothing},
        jmes_ast::Union{JMESNode, Nothing},
    )
    each_scope_snapshots(
        tape;
        commit_filter = (commit, raw, ctx) ->
            isnothing(commit_label) || commit.label == commit_label,
        scope_filter = function (scope, commit, raw, ctx, scope_ord)
            (!isnothing(scope_label) && !any(==(scope_label), scope.labels)) && return false
            (!isnothing(src_file) && !_src_file_match(scope, src_file)) && return false
            return true
        end,
        on_scope = function (scope, commit, raw, ctx, scope_ord)
            # JMESPath post-filter on raw commit dict
            # (scopes don't have independent raw dicts; filter on parent commit raw)
            if !isnothing(jmes_ast)
                _jmes_is_truthy(jmespath_eval(jmes_ast, raw)) || return nothing
            end
            push!(results, scope)
            return nothing
        end,
    )
    return nothing
end
