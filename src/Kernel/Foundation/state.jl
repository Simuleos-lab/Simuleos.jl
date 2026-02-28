# ============================================================
# base.jl — Keyword constructors and basic operations
# ============================================================

import UUIDs: uuid4

# -- SimOs --
function SimOs(;
        bootstrap = Dict{String, Any}(),
        sandbox = nothing,
        project = nothing,
        home = nothing,
        worksession = nothing,
        settings_stack = nothing,
        shared_scopes::Dict{String, ScopeSnapshot} = Dict{String, ScopeSnapshot}(),
        sqlite_db = nothing,
        sqlite_db_path::Union{Nothing, String} = nothing,
    )
    SimOs(bootstrap, sandbox, project, home, worksession, settings_stack, shared_scopes, sqlite_db, sqlite_db_path)
end

# -- SimuleosProject --
function SimuleosProject(;
        id = nothing,
        root_path::String,
        simuleos_dir::String = _simuleos_dir(root_path),
        blobstorage::BlobStorage = BlobStorage(blobs_dir(simuleos_dir)),
        git_handler::Union{Nothing, GitHandler} = nothing,
    )
    SimuleosProject(id, root_path, simuleos_dir, blobstorage, git_handler)
end

# -- BlobStorage from project --
BlobStorage(proj::SimuleosProject) = BlobStorage(blobs_dir(proj.simuleos_dir))

# -- WorkSession --
function WorkSession(;
        session_id::Base.UUID = uuid4(),
        labels::Vector{String} = String[],
        stage::CaptureTree = CaptureTree(),
        pending_commits::Vector{CaptureTree} = CaptureTree[],
        capture_policy::CapturePolicy = CapturePolicy(),
        is_finalized::Bool = false,
        metadata::Dict{String, Any} = Dict{String, Any}(),
        context_hash_reg::Dict{String, String} = Dict{String, String}(),
        queue_counters::Dict{String, Int} = Dict{String, Int}(),
        simignore_rules::Vector{Dict{Symbol, Any}} = Dict{Symbol, Any}[],
        capture_filter_defs::Dict{String, Vector{Dict{Symbol, Any}}} = Dict{String, Vector{Dict{Symbol, Any}}}(),
        capture_filter_bindings::Dict{String, Vector{String}} = Dict{String, Vector{String}}(),
        settings_access_log::Union{Nothing, Dict{String, Any}} = nothing,
        settings_access_tracking::Bool = true,
        source_capture::Union{Nothing, SourceSnapshot} = nothing,
        environment_capture::Union{Nothing, EnvironmentSnapshot} = nothing,
    )
    WorkSession(
        session_id,
        labels,
        stage,
        pending_commits,
        capture_policy,
        is_finalized,
        metadata,
        context_hash_reg,
        queue_counters,
        simignore_rules,
        capture_filter_defs,
        capture_filter_bindings,
        settings_access_log,
        settings_access_tracking,
        source_capture,
        environment_capture,
    )
end

# -- show methods --

function Base.show(io::IO, ref::RecordRef)
    print(io, "RecordRef(", ref.short, ")")
end

Base.print(io::IO, ref::RecordRef) = print(io, ref.short)

function Base.show(io::IO, ref::BlobRef)
    h = length(ref.hash) > 12 ? ref.hash[1:12] * "..." : ref.hash
    print(io, "BlobRef(", h, ")")
end

function Base.show(io::IO, v::InlineScopeVariable)
    print(io, "Inline(", v.level, ", ", v.type_short, ")")
end

function Base.show(io::IO, v::BlobScopeVariable)
    print(io, "Blob(", v.level, ", ", v.type_short, ", ", v.blob_ref, ")")
end

function Base.show(io::IO, v::VoidScopeVariable)
    print(io, "Void(", v.level, ", ", v.type_short, ")")
end

function Base.show(io::IO, v::HashedScopeVariable)
    h = length(v.value_hash) > 12 ? v.value_hash[1:12] * "..." : v.value_hash
    print(io, "Hashed(", v.level, ", ", v.type_short, ", ", h, ")")
end

function Base.show(io::IO, scope::ScopeSnapshot)
    nv = length(scope.variables)
    print(io, "ScopeSnapshot(labels=", scope.labels, ", vars=", nv, ")")
end

function Base.show(io::IO, ::MIME"text/plain", scope::ScopeSnapshot)
    println(io, "ScopeSnapshot")
    println(io, "  labels: ", scope.labels)
    println(io, "  variables (", length(scope.variables), "):")
    for (name, var) in sort(collect(scope.variables); by=first)
        if var isa InlineScopeVariable
            val_str = sprint(show, var.value; context=:compact=>true)
            if length(val_str) > 60
                val_str = val_str[1:57] * "..."
            end
            println(io, "    ", name, " [", var.level, "] ", var.type_short, " = ", val_str)
        elseif var isa BlobScopeVariable
            println(io, "    ", name, " [", var.level, "] ", var.type_short, " blob:", var.blob_ref)
        elseif var isa HashedScopeVariable
            h = length(var.value_hash) > 12 ? var.value_hash[1:12] * "..." : var.value_hash
            println(io, "    ", name, " [", var.level, "] ", var.type_short, " hash:", h)
        elseif var isa VoidScopeVariable
            println(io, "    ", name, " [", var.level, "] ", var.type_short, " void")
        end
    end
    if !isempty(scope.metadata)
        println(io, "  metadata:")
        for (k, v) in scope.metadata
            println(io, "    ", k, " = ", v)
        end
    end
end

function Base.show(io::IO, tree::CaptureTree)
    lbl = isempty(tree.label) ? "(unlabeled)" : tree.label
    ns = count(s -> s isa ScopeSnapshot, tree.snapshots)
    nc = length(tree.children)
    print(io, "CaptureTree(", lbl, ", snapshots=", ns, ", children=", nc, ")")
end

function Base.show(io::IO, proj::SimuleosProject)
    id = isnothing(proj.id) ? "?" : proj.id
    print(io, "SimuleosProject(", id, ", ", proj.root_path, ")")
end

function Base.show(io::IO, ws::WorkSession)
    print(io, "WorkSession(", ws.session_id, ", labels=", ws.labels, ")")
end

function _capture_tree_stats(tree::CaptureTree)
    snapshot_count = length(tree.snapshots)
    scope_count = count(s -> s isa ScopeSnapshot, tree.snapshots)

    for child in tree.children
        child_stats = _capture_tree_stats(child)
        snapshot_count += child_stats.snapshot_count
        scope_count += child_stats.scope_count
    end

    return (snapshot_count = snapshot_count, scope_count = scope_count)
end

function _pending_commit_stats(ws::WorkSession)
    snapshot_count = 0
    scope_count = 0
    for commit in ws.pending_commits
        stats = _capture_tree_stats(commit)
        snapshot_count += stats.snapshot_count
        scope_count += stats.scope_count
    end
    return (snapshot_count = snapshot_count, scope_count = scope_count)
end

function _shared_scope_var_count(shared_scopes::Dict{String, ScopeSnapshot})::Int
    total = 0
    for scope in values(shared_scopes)
        total += length(scope.variables)
    end
    return total
end

function Base.show(io::IO, sim::SimOs)
    project_state = isnothing(sim.project) ? "none" : "ready"
    session_state = isnothing(sim.worksession) ? "none" : "active"
    settings_layers = isnothing(sim.settings_stack) ? 0 : length(sim.settings_stack.layers)
    sqlite_state = isnothing(sim.sqlite_db) ? "closed" : "open"

    print(
        io,
        "SimOs(project=", project_state,
        ", session=", session_state,
        ", settings_layers=", settings_layers,
        ", shared_scopes=", length(sim.shared_scopes),
        ", sqlite=", sqlite_state,
        ")",
    )
end

function Base.show(io::IO, ::MIME"text/plain", sim::SimOs)
    println(io, "SimOs")
    println(io, "  bootstrap_keys: ", length(sim.bootstrap))

    if isnothing(sim.sandbox)
        println(io, "  sandbox: none")
    else
        sb = sim.sandbox
        println(io, "  sandbox: ", sb.origin, " (cleanup_on_reset=", sb.cleanup_on_reset, ")")
        println(io, "    root: ", sb.root_path)
    end

    if isnothing(sim.home)
        println(io, "  home: none")
    else
        println(io, "  home: ", sim.home.path)
    end

    if isnothing(sim.project)
        println(io, "  project: none")
    else
        proj = sim.project
        id = isnothing(proj.id) ? "?" : proj.id
        git_state = isnothing(proj.git_handler) ? "none" : "attached"
        println(io, "  project: ", id, " (git=", git_state, ")")
        println(io, "    root: ", proj.root_path)
    end

    if isnothing(sim.settings_stack)
        println(io, "  settings: none")
    else
        stack = sim.settings_stack
        println(
            io,
            "  settings: layers=", length(stack.layers),
            ", version=", stack.version,
            ", registry=", length(stack.registry),
            ", cached=", length(stack.effective),
            ", missing_cached=", length(stack.effective_missing),
            ", complete=", stack.effective_complete,
        )
    end

    if isnothing(sim.worksession)
        println(io, "  session: none")
    else
        ws = sim.worksession
        stage_stats = _capture_tree_stats(ws.stage)
        pending_stats = _pending_commit_stats(ws)
        println(io, "  session: ", ws.session_id)
        println(
            io,
            "    labels=", length(ws.labels),
            ", finalized=", ws.is_finalized,
            ", staged_scopes=", stage_stats.scope_count,
            ", staged_snapshots=", stage_stats.snapshot_count,
            ", pending_commits=", length(ws.pending_commits),
            ", pending_scopes=", pending_stats.scope_count,
            ", pending_snapshots=", pending_stats.snapshot_count,
        )
        println(
            io,
            "    context_hashes=", length(ws.context_hash_reg),
            ", capture_filters=", length(ws.capture_filter_defs),
            ", queue_counters=", length(ws.queue_counters),
        )
    end

    shared_count = length(sim.shared_scopes)
    shared_vars = _shared_scope_var_count(sim.shared_scopes)
    println(io, "  shared_scopes: ", shared_count, " (vars=", shared_vars, ")")

    if isnothing(sim.sqlite_db)
        println(io, "  sqlite: closed")
    else
        path = isnothing(sim.sqlite_db_path) ? "(path unknown)" : sim.sqlite_db_path
        println(io, "  sqlite: open")
        println(io, "    path: ", path)
    end
end
