# ============================================================
# tapeio/registry.jl — TapeRegistry: in-memory tape path index
#
# Registration happens once per tape on first write (via _ensure_tape_metadata!).
# Rebuild scans disk to repopulate the registry from conventions.
# ============================================================

# --- Registration (called by tape machinery on creation) ---

function tape_registry_register!(
        registry::TapeRegistry,
        path::String;
        source::Symbol = :unknown,
        meta::Dict{String, Any} = Dict{String, Any}(),
    )::Nothing
    key = abspath(path)
    haskey(registry.entries, key) && return nothing
    registry.entries[key] = TapeRegistryEntry(key, source, meta)
    return nothing
end

function tape_registry_register!(
        proj::SimuleosProject,
        path::String;
        source::Symbol = :unknown,
        meta::Dict{String, Any} = Dict{String, Any}(),
    )::Nothing
    tape_registry_register!(proj.tape_registry, path; source, meta)
    return nothing
end

# --- Query ---

function tape_registry_entries(registry::TapeRegistry)::Vector{TapeRegistryEntry}
    return collect(values(registry.entries))
end

function tape_registry_entries(
        registry::TapeRegistry,
        source::Symbol,
    )::Vector{TapeRegistryEntry}
    return [e for e in values(registry.entries) if e.source === source]
end

function tape_registry_tapes(registry::TapeRegistry)::Vector{TapeIO}
    return [TapeIO(e.path) for e in values(registry.entries)]
end

function tape_registry_tapes(registry::TapeRegistry, source::Symbol)::Vector{TapeIO}
    return [TapeIO(e.path) for e in values(registry.entries) if e.source === source]
end

tape_registry_has(registry::TapeRegistry, path::String)::Bool =
    haskey(registry.entries, abspath(path))

tape_registry_count(registry::TapeRegistry)::Int = length(registry.entries)

# --- Rebuild from disk (cold start / recovery) ---

function tape_registry_rebuild!(proj::SimuleosProject)::Nothing
    registry = proj.tape_registry
    empty!(registry.entries)
    _rebuild_session_tapes!(registry, proj)
    _rebuild_blob_tapes!(registry, proj)
    return nothing
end

function _rebuild_session_tapes!(registry::TapeRegistry, proj::SimuleosProject)::Nothing
    sdir = sessions_dir(proj)
    isdir(sdir) || return nothing

    for entry in readdir(sdir)
        session_dir = joinpath(sdir, entry)
        isdir(session_dir) || continue
        tapes_dir = joinpath(session_dir, TAPES_DIR)
        isdir(tapes_dir) || continue

        for tape_name in readdir(tapes_dir)
            tape_path = joinpath(tapes_dir, tape_name)
            # Fragmented tapes are directories, single-file tapes are .jsonl files
            if isdir(tape_path) || endswith(lowercase(tape_name), ".jsonl")
                tape_registry_register!(registry, tape_path;
                    source = :session,
                    meta = Dict{String, Any}(
                        "session_id" => entry,
                        "tape_name" => tape_name,
                    ),
                )
            end
        end
    end
    return nothing
end

function _rebuild_blob_tapes!(registry::TapeRegistry, proj::SimuleosProject)::Nothing
    btdir = blob_tapes_dir(proj.blobstorage)
    isdir(btdir) || return nothing

    for fname in readdir(btdir)
        endswith(lowercase(fname), ".jsonl") || continue
        fpath = joinpath(btdir, fname)
        isfile(fpath) || continue
        shard_prefix = splitext(fname)[1]
        tape_registry_register!(registry, fpath;
            source = :blobstorage,
            meta = Dict{String, Any}("shard_prefix" => shard_prefix),
        )
    end
    return nothing
end

# --- Ensure registry is populated (lazy rebuild on first query) ---

function tape_registry_ensure!(proj::SimuleosProject)::Nothing
    isempty(proj.tape_registry.entries) || return nothing
    tape_registry_rebuild!(proj)
    return nothing
end
