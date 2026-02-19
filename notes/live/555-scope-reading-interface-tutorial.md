# Scope Reading Interface Tutorial

Date: 2026-02-18

## Goal
- Read recorded scope commits from a session tape using the current interface.

## Minimal read flow

```julia
using UUIDs
import Simuleos

# 1) Build tape handle from project .simuleos dir + session id
simuleos_dir = "/path/to/project/.simuleos"
session_id = UUID("11111111-2222-3333-4444-555555555555")
tape = Simuleos.Kernel.TapeIO(
    Simuleos.Kernel.tape_path(simuleos_dir, session_id)
)

# 2) Iterate typed commits (ScopeCommit)
for commit in Simuleos.Kernel.iterate_tape(tape)
    println("commit_label = ", commit.commit_label)
    println("timestamp = ", get(commit.metadata, "timestamp", ""))

    for scope in commit.scopes
        println("  labels = ", scope.labels)

        for (name, variable) in scope.variables
            println("    ", name, " => ", typeof(variable))
        end
    end
end
```

## Eager collect

```julia
commits = collect(Simuleos.Kernel.iterate_tape(tape))
# or:
commits2 = collect(Vector{Simuleos.Kernel.ScopeCommit}, tape)
```

## Variable modes
- `Simuleos.Kernel.InlineScopeVariable`: value is in `variable.value`
- `Simuleos.Kernel.BlobScopeVariable`: payload is in blob storage, address at `variable.blob_ref`
- `Simuleos.Kernel.VoidScopeVariable`: only type/source metadata, no stored value

## Read blob payloads (when variable is blob-backed)

```julia
# You need a BlobStorage driver for the same project.
project = Simuleos.Kernel.SimuleosProject(
    id = "project-id",
    root_path = "/path/to/project",
    simuleos_dir = simuleos_dir
)
storage = Simuleos.Kernel.BlobStorage(project)

first_commit = first(commits)
first_scope = first(first_commit.scopes)

for variable in values(first_scope.variables)
    if variable isa Simuleos.Kernel.BlobScopeVariable
        payload = Simuleos.Kernel.blob_read(storage, variable.blob_ref)
        @show payload
    end
end
```
