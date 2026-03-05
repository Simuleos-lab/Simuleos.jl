# ============================================================
# scopetapes/read.jl — Semantic scope readers over agnostic TapeIO
# ============================================================

_scope_record_is_commit(raw::AbstractDict)::Bool =
    _record_class_id_value(raw; default = "") == _CAPTURE_COMMIT_CLASS_ID

_scope_commit_line_filter(line::AbstractString, ctx::TapeRecordFilterCtx)::Bool =
    occursin("\"$(CLASS_ID_KEY)\":\"$(_CAPTURE_COMMIT_CLASS_ID)\"", line)

_commit_scope_snapshots(commit::RecCaptureCommitV1)::Vector{SnapScopeV1} =
    commit_scope_snapshots(commit)

_normalize_scope_fetch_limit(limit::Nothing) = nothing
function _normalize_scope_fetch_limit(limit::Integer)
    limit > 0 || error("Expected `limit > 0`, got `$(limit)`.")
    return Int(limit)
end

"""
    each_scope_commits(tape::TapeIO; line_filter, record_filter, commit_filter, on_commit, reverse=false) -> Int

Semantic commit reader: scans tape records, rehydrates commit objects, and invokes
`on_commit(commit, raw, ctx)` for accepted commits.
"""
function each_scope_commits(
        tape::TapeIO;
        line_filter::Function = _scope_commit_line_filter,
        record_filter::Function = (raw, ctx) -> true,
        commit_filter::Function = (commit, raw, ctx) -> true,
        on_commit::Function = (commit, raw, ctx) -> nothing,
        reverse::Bool = false,
    )::Int
    accepted = 0
    each_tape_records(
        tape;
        reverse = reverse,
        line_filter = function (line, ctx)
            _scope_commit_line_filter(line, ctx) || return false
            return line_filter(line, ctx)
        end,
        json_filter = function (raw, ctx)
            _scope_record_is_commit(raw) || return false
            return record_filter(raw, ctx)
        end,
        on_record = function (raw, ctx)
            commit = decode_scope_commit_record(raw)
            if commit_filter(commit, raw, ctx)
                on_commit(commit, raw, ctx)
                accepted += 1
            end
            return nothing
        end,
    )
    return accepted
end

"""
    fetch_scope_commits(tape::TapeIO; line_filter, record_filter, commit_filter, reverse=false, limit=nothing) -> Vector{RecCaptureCommitV1}

Materialize semantic commit reads.
"""
function fetch_scope_commits(
        tape::TapeIO;
        line_filter::Function = _scope_commit_line_filter,
        record_filter::Function = (raw, ctx) -> true,
        commit_filter::Function = (commit, raw, ctx) -> true,
        reverse::Bool = false,
        limit::Union{Nothing, Integer} = nothing,
    )::Vector{RecCaptureCommitV1}
    max_rows = _normalize_scope_fetch_limit(limit)
    commits = RecCaptureCommitV1[]
    each_scope_commits(
        tape;
        line_filter = line_filter,
        record_filter = record_filter,
        commit_filter = commit_filter,
        reverse = reverse,
        on_commit = function (commit, raw, ctx)
            push!(commits, commit)
            !isnothing(max_rows) && length(commits) >= max_rows && stop!(ctx)
            return nothing
        end,
    )
    return commits
end

"""
    find_scope_commits(tape::TapeIO; line_filter, record_filter, commit_filter, reverse=false, limit=nothing) -> Vector{RecCaptureCommitV1}

Semantic finder alias over `fetch_scope_commits`.
"""
function find_scope_commits(
        tape::TapeIO;
        line_filter::Function = _scope_commit_line_filter,
        record_filter::Function = (raw, ctx) -> true,
        commit_filter::Function = (commit, raw, ctx) -> true,
        reverse::Bool = false,
        limit::Union{Nothing, Integer} = nothing,
    )::Vector{RecCaptureCommitV1}
    return fetch_scope_commits(
        tape;
        line_filter = line_filter,
        record_filter = record_filter,
        commit_filter = commit_filter,
        reverse = reverse,
        limit = limit,
    )
end

"""
    latest_scope_commit(tape::TapeIO; line_filter, record_filter, commit_filter) -> Union{RecCaptureCommitV1, Nothing}

Return the latest semantic commit match in tape order.
"""
function latest_scope_commit(
        tape::TapeIO;
        line_filter::Function = _scope_commit_line_filter,
        record_filter::Function = (raw, ctx) -> true,
        commit_filter::Function = (commit, raw, ctx) -> true,
    )::Union{RecCaptureCommitV1, Nothing}
    commits = fetch_scope_commits(
        tape;
        line_filter = line_filter,
        record_filter = record_filter,
        commit_filter = commit_filter,
        reverse = true,
        limit = 1,
    )
    return isempty(commits) ? nothing : commits[1]
end

"""
    table_scope_commits(tape::TapeIO; line_filter, record_filter, commit_filter, row_builder, reverse=false, limit=nothing) -> Vector

Map semantic commit reads to table rows via `row_builder(commit, raw, ctx)`.
"""
function table_scope_commits(
        tape::TapeIO;
        line_filter::Function = _scope_commit_line_filter,
        record_filter::Function = (raw, ctx) -> true,
        commit_filter::Function = (commit, raw, ctx) -> true,
        row_builder::Function = (commit, raw, ctx) -> Dict{Symbol, Any}(
            :commit_label => commit.label,
            :scope_count => length(_commit_scope_snapshots(commit)),
            :tape_file => ctx.file,
            :tape_line_no => ctx.line_no,
        ),
        reverse::Bool = false,
        limit::Union{Nothing, Integer} = nothing,
    )::Vector
    max_rows = _normalize_scope_fetch_limit(limit)
    rows = Any[]
    each_scope_commits(
        tape;
        line_filter = line_filter,
        record_filter = record_filter,
        commit_filter = commit_filter,
        reverse = reverse,
        on_commit = function (commit, raw, ctx)
            push!(rows, row_builder(commit, raw, ctx))
            !isnothing(max_rows) && length(rows) >= max_rows && stop!(ctx)
            return nothing
        end,
    )
    return rows
end

"""
    each_scope_snapshots(tape::TapeIO; line_filter, record_filter, commit_filter, scope_filter, on_scope, reverse=false) -> Int

Semantic scope reader: scans commit records, rehydrates scope snapshots, and invokes
`on_scope(scope, commit, raw, ctx, scope_ord)` for accepted scope rows.
"""
function each_scope_snapshots(
        tape::TapeIO;
        line_filter::Function = _scope_commit_line_filter,
        record_filter::Function = (raw, ctx) -> true,
        commit_filter::Function = (commit, raw, ctx) -> true,
        scope_filter::Function = (scope, commit, raw, ctx, scope_ord) -> true,
        on_scope::Function = (scope, commit, raw, ctx, scope_ord) -> nothing,
        reverse::Bool = false,
    )::Int
    accepted = 0
    each_scope_commits(
        tape;
        line_filter = line_filter,
        record_filter = record_filter,
        commit_filter = commit_filter,
        reverse = reverse,
        on_commit = function (commit, raw, ctx)
            scopes = _commit_scope_snapshots(commit)
            ords = reverse ? Base.reverse(eachindex(scopes)) : eachindex(scopes)
            for scope_ord in ords
                scope = scopes[scope_ord]
                if scope_filter(scope, commit, raw, ctx, scope_ord)
                    on_scope(scope, commit, raw, ctx, scope_ord)
                    accepted += 1
                end
                ctx.stop && break
            end
            return nothing
        end,
    )
    return accepted
end

"""
    fetch_scope_snapshots(tape::TapeIO; line_filter, record_filter, commit_filter, scope_filter, reverse=false, limit=nothing) -> Vector{SnapScopeV1}

Materialize semantic scope reads.
"""
function fetch_scope_snapshots(
        tape::TapeIO;
        line_filter::Function = _scope_commit_line_filter,
        record_filter::Function = (raw, ctx) -> true,
        commit_filter::Function = (commit, raw, ctx) -> true,
        scope_filter::Function = (scope, commit, raw, ctx, scope_ord) -> true,
        reverse::Bool = false,
        limit::Union{Nothing, Integer} = nothing,
    )::Vector{SnapScopeV1}
    max_rows = _normalize_scope_fetch_limit(limit)
    scopes = SnapScopeV1[]
    each_scope_snapshots(
        tape;
        line_filter = line_filter,
        record_filter = record_filter,
        commit_filter = commit_filter,
        scope_filter = scope_filter,
        reverse = reverse,
        on_scope = function (scope, commit, raw, ctx, scope_ord)
            push!(scopes, scope)
            !isnothing(max_rows) && length(scopes) >= max_rows && stop!(ctx)
            return nothing
        end,
    )
    return scopes
end

"""
    find_scope_snapshots(tape::TapeIO; line_filter, record_filter, commit_filter, scope_filter, reverse=false, limit=nothing) -> Vector{SnapScopeV1}

Semantic finder alias over `fetch_scope_snapshots`.
"""
function find_scope_snapshots(
        tape::TapeIO;
        line_filter::Function = _scope_commit_line_filter,
        record_filter::Function = (raw, ctx) -> true,
        commit_filter::Function = (commit, raw, ctx) -> true,
        scope_filter::Function = (scope, commit, raw, ctx, scope_ord) -> true,
        reverse::Bool = false,
        limit::Union{Nothing, Integer} = nothing,
    )::Vector{SnapScopeV1}
    return fetch_scope_snapshots(
        tape;
        line_filter = line_filter,
        record_filter = record_filter,
        commit_filter = commit_filter,
        scope_filter = scope_filter,
        reverse = reverse,
        limit = limit,
    )
end

"""
    latest_scope_snapshot(tape::TapeIO; line_filter, record_filter, commit_filter, scope_filter) -> Union{SnapScopeV1, Nothing}

Return the latest semantic scope match in tape order.
"""
function latest_scope_snapshot(
        tape::TapeIO;
        line_filter::Function = _scope_commit_line_filter,
        record_filter::Function = (raw, ctx) -> true,
        commit_filter::Function = (commit, raw, ctx) -> true,
        scope_filter::Function = (scope, commit, raw, ctx, scope_ord) -> true,
    )::Union{SnapScopeV1, Nothing}
    scopes = fetch_scope_snapshots(
        tape;
        line_filter = line_filter,
        record_filter = record_filter,
        commit_filter = commit_filter,
        scope_filter = scope_filter,
        reverse = true,
        limit = 1,
    )
    return isempty(scopes) ? nothing : scopes[1]
end

function _default_scope_row(
        scope::SnapScopeV1,
        commit::RecCaptureCommitV1,
        raw::AbstractDict,
        ctx::TapeRecordFilterCtx,
        scope_ord::Int,
    )::Dict{Symbol, Any}
    row = Dict{Symbol, Any}()
    row[:commit_label] = commit.label
    row[:scope_labels] = join(scope.labels, ";")
    row[:scope_ord] = scope_ord
    row[:tape_file] = ctx.file
    row[:tape_line_no] = ctx.line_no
    for (k, v) in scope.metadata
        row[k] = v
    end
    for (name, var) in scope.variables
        row[name] = var
    end
    return row
end

"""
    table_scope_snapshots(tape::TapeIO; line_filter, record_filter, commit_filter, scope_filter, row_builder, reverse=false, limit=nothing) -> Vector

Map semantic scope reads to table rows via
`row_builder(scope, commit, raw, ctx, scope_ord)`.
"""
function table_scope_snapshots(
        tape::TapeIO;
        line_filter::Function = _scope_commit_line_filter,
        record_filter::Function = (raw, ctx) -> true,
        commit_filter::Function = (commit, raw, ctx) -> true,
        scope_filter::Function = (scope, commit, raw, ctx, scope_ord) -> true,
        row_builder::Function = _default_scope_row,
        reverse::Bool = false,
        limit::Union{Nothing, Integer} = nothing,
    )::Vector
    max_rows = _normalize_scope_fetch_limit(limit)
    rows = Any[]
    each_scope_snapshots(
        tape;
        line_filter = line_filter,
        record_filter = record_filter,
        commit_filter = commit_filter,
        scope_filter = scope_filter,
        reverse = reverse,
        on_scope = function (scope, commit, raw, ctx, scope_ord)
            push!(rows, row_builder(scope, commit, raw, ctx, scope_ord))
            !isnothing(max_rows) && length(rows) >= max_rows && stop!(ctx)
            return nothing
        end,
    )
    return rows
end

scope_value(var::InlineScopeVariable, proj::SimuleosProject) = var.value
scope_value(var::BlobScopeVariable, proj::SimuleosProject) = blob_read(proj.blobstorage, var.blob_ref)
scope_value(var::VoidScopeVariable, proj::SimuleosProject) = nothing
scope_value(var::HashedScopeVariable, proj::SimuleosProject) = nothing
scope_value(var::InlineScopeVariable, ::Nothing) = var.value
scope_value(var::VoidScopeVariable, ::Nothing) = nothing
scope_value(var::HashedScopeVariable, ::Nothing) = nothing
function scope_value(var::BlobScopeVariable, ::Nothing)
    error("Cannot resolve blob-backed scope variable `$(var.type_short)` without a project.")
end

scope_expand_level(var::InlineScopeVariable)::Symbol = var.level
scope_expand_level(var::BlobScopeVariable)::Symbol = var.level
scope_expand_level(var::VoidScopeVariable)::Symbol = var.level
scope_expand_level(var::HashedScopeVariable)::Symbol = var.level

function _scope_expand_runtime_impl(
        variables::Dict{Symbol, ScopeVariable},
        proj,
        name::Symbol,
    )::Tuple{Symbol, Any}
    haskey(variables, name) || error("Variable `$(name)` not found in scope.")
    var = variables[name]
    return (scope_expand_level(var), scope_value(var, proj))
end

"""
    scope_expand_runtime!(scope::SnapScopeV1, proj, name::Symbol) -> Tuple{Symbol, Any}

Resolve one captured scope variable for runtime scope binding.
"""
function scope_expand_runtime!(
        scope::SnapScopeV1,
        proj,
        name::Symbol,
    )::Tuple{Symbol, Any}
    return _scope_expand_runtime_impl(scope.variables, proj, name)
end

"""
    scope_expand_runtime!(scope::SnapSharedV1, proj, name::Symbol) -> Tuple{Symbol, Any}

Resolve one captured shared variable for runtime scope binding.
"""
function scope_expand_runtime!(
        scope::SnapSharedV1,
        proj,
        name::Symbol,
    )::Tuple{Symbol, Any}
    return _scope_expand_runtime_impl(scope.variables, proj, name)
end

"""
    scope_expand_setglobal!(target_module::Module, name::Symbol, value)

Set an existing global in `target_module`.
"""
function scope_expand_setglobal!(target_module::Module, name::Symbol, value)
    isdefined(target_module, name) || error(
        "Global `$(name)` is not defined in module `$(target_module)`. " *
        "Define it before calling @simos scope.bind."
    )
    Core.setglobal!(target_module, name, value)
    return value
end
