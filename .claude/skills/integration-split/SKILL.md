---
name: integration-split
description: Split and rename Julia files by integration level (I0x/I1x/I2x/I3x) based on SimuleOs I Axis architecture
disable-model-invocation: true
user-invocable: true
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(mv *, rm *)
argument-hint: [optional: module-path]
---

# Integration-Level File Grouping

Split and rename Julia source files based on their integration level according to SimuleOs's I Axis architecture.

## Context

SimuleOs uses an **Integration Axis (I Axis)** to classify functions by how they access system state:

- **I0x**: Pure utilities, no SimOs/SIMOS access
- **I1x**: Explicit dependencies as arguments (takes SimOs or subsystem objects)
- **I2x**: Reaches inside SimOs (accesses `simos.recorder`, etc.)
- **I3x**: Resolves globals internally (uses `SIMOS[]`)

Read the full I Axis definition: `notes/index/the-integration-axis.md`

## Goal

Organize code files by integration level:
- Rename single-level files: `blob.jl` → `blob-I0x.jl`
- Split mixed-level files: `loaders.jl` → `loaders-I0x.jl` + `loaders-I1x.jl`
- Update module includes and maintain proper ordering (I0x → I1x → I2x → I3x)

## Workflow

### Step 1: Read I Axis Documentation

Read `notes/index/the-integration-axis.md` to understand integration level definitions.

### Step 2: Determine Target

If `$ARGUMENTS` is provided, use it as the target path. Otherwise, ask the user:

```
Which module or folder should I process?
Examples:
- src/Recorder
- src/Kernel/querynav
- src/Reader
```

### Step 3: Scan and Classify

For each `.jl` file in the target:

1. Read the file
2. Classify each function by integration level:
   - **I0x**: No SimOs/SIMOS references, pure utilities
   - **I1x**: Takes handler/SimOs objects as arguments, no internal global access
   - **I2x**: Takes SimOs argument, accesses inner globals like `simos.recorder`
   - **I3x**: No SimOs argument, uses `SIMOS[]` internally

3. Classify file as:
   - **Pure**: All functions at same level (e.g., all I0x)
   - **Mixed**: Functions at different levels (e.g., I0x + I1x)
   - **Empty/Types**: No functions, just types/constants

**Ambiguous functions**: If you cannot determine the level, note it for manual review but continue processing other functions.

**Files with no functions**: Classify as I0x by default.

### Step 4: Generate Plan

Create a refactoring plan showing:

```
Target: src/Kernel/querynav

Files to rename (pure, single level):
  handlers.jl → handlers-I1x.jl (all functions are I1x)

Files to split (mixed levels):
  loaders.jl →
    - loaders-I0x.jl (3 functions: _raw_to_variable_record, _raw_to_scope_record, _raw_to_commit_record)
    - loaders-I1x.jl (4 functions: iterate_raw_tape, iterate_tape, load_raw_blob, load_blob)

Module updates:
  src/Kernel/Kernel.jl
    - include("querynav/loaders.jl") → delete
    + include("querynav/loaders-I0x.jl")
    + include("querynav/handlers-I1x.jl")
    + include("querynav/loaders-I1x.jl")

Ambiguous functions (manual review needed):
  [list any functions you couldn't classify]

Files to delete:
  - src/Kernel/querynav/loaders.jl
```

### Step 5: Get Approval

Present the plan and ask:
```
Review the plan above. Proceed with execution? (yes/no)
```

If the user says no or asks for changes, adjust the plan and ask again.

### Step 6: Execute

Once approved:

1. **Rename pure files**: Use `Bash(mv ...)`
2. **Split mixed files**: Use `Write` to create new files with proper content and headers
3. **Delete old files**: Use `Bash(rm ...)` for replaced mixed files
4. **Update includes**: Use `Edit` to update module entrypoint files
   - Preserve logical grouping
   - Order by I-level (I0x → I1x → I2x → I3x) within each group
   - Standardize spacing and formatting

5. **Verify**: Use `Grep` to check for any remaining references to old filenames

### Step 7: Summary

Report execution results:
```
✓ Renamed 3 files
✓ Split 1 file into 2
✓ Updated 1 module include
✓ Deleted 1 old file
✓ No stale references found

Ambiguous functions requiring manual review:
  - src/Kernel/querynav/loaders.jl:45 _maybe_serialize_thing()
```

## Rules

- Use exact suffixes: `-I0x`, `-I1x`, `-I2x`, `-I3x`
- Create as many files as there are integration levels present
- No backward compatibility shims or deprecated aliases
- Preserve comments within functions, but update file-level headers
- Keep code clean and simple
- Do not add exports (per AGENT: IMPORTANT comments in module files)

## File Headers

When creating new split files, use headers like:

```julia
# [Description] (all I0x — [details])
```

Examples:
- `# Record constructors from raw Dict data (all I0x — pure data transformation)`
- `# Loading functions for tape and blob data (all I1x — takes handler objects as arguments)`

## Include Block Formatting

When updating module includes, standardize to:

```julia
# Subsystem name
include("subfolder/file-I0x.jl")
include("subfolder/file-I1x.jl")
include("subfolder/other-I0x.jl")
include("subfolder/other-I1x.jl")
```

Preserve logical grouping (e.g., all querynav includes together), but order by I-level within groups.

## Notes

- This skill is project-specific to SimuleOs
- Always read the I Axis doc first to ensure consistent classification
- When in doubt about a function's level, err on the side of caution and mark for manual review
- The goal is clarity and maintainability, not perfection on first pass
