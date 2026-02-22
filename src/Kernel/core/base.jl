# ============================================================
# base.jl — Keyword constructors and basic operations
# ============================================================

import UUIDs: uuid4

# -- SimOs --
function SimOs(;
        bootstrap = Dict{String, Any}(),
        project = nothing,
        home = nothing,
        worksession = nothing,
        settings = Dict{String, Any}(),
    )
    SimOs(bootstrap, project, home, worksession, settings)
end

# -- SimuleosProject --
function SimuleosProject(;
        id = nothing,
        root_path::String,
        simuleos_dir::String = _simuleos_dir(root_path),
        blobstorage::BlobStorage = BlobStorage(blobs_dir(simuleos_dir)),
        git_handler = nothing,
    )
    SimuleosProject(id, root_path, simuleos_dir, blobstorage, git_handler)
end

# -- BlobStorage from project --
BlobStorage(proj::SimuleosProject) = BlobStorage(blobs_dir(proj.simuleos_dir))

# -- WorkSession --
function WorkSession(;
        session_id::Base.UUID = uuid4(),
        labels::Vector{String} = String[],
        stage::ScopeStage = ScopeStage(),
        pending_commits::Vector{ScopeCommit} = ScopeCommit[],
        is_finalized::Bool = false,
        metadata::Dict{String, Any} = Dict{String, Any}(),
        context_hash_reg::Dict{String, String} = Dict{String, String}(),
        simignore_rules::Vector{Dict{Symbol, Any}} = Dict{Symbol, Any}[],
        _settings_cache::Dict{String, Any} = Dict{String, Any}(),
    )
    WorkSession(session_id, labels, stage, pending_commits, is_finalized, metadata, context_hash_reg, simignore_rules, _settings_cache)
end

# -- show methods --

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

function Base.show(io::IO, scope::SimuleosScope)
    nv = length(scope.variables)
    print(io, "SimuleosScope(labels=", scope.labels, ", vars=", nv, ")")
end

function Base.show(io::IO, ::MIME"text/plain", scope::SimuleosScope)
    println(io, "SimuleosScope")
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

function Base.show(io::IO, commit::ScopeCommit)
    lbl = isempty(commit.commit_label) ? "(unlabeled)" : commit.commit_label
    print(io, "ScopeCommit(", lbl, ", scopes=", length(commit.scopes), ")")
end

function Base.show(io::IO, proj::SimuleosProject)
    id = isnothing(proj.id) ? "?" : proj.id
    print(io, "SimuleosProject(", id, ", ", proj.root_path, ")")
end

function Base.show(io::IO, ws::WorkSession)
    print(io, "WorkSession(", ws.session_id, ", labels=", ws.labels, ")")
end
