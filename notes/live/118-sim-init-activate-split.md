# sim_init / sim_activate Split — Decisions

**Issue**: Split the current `sim_activate` into two distinct commands: `sim_init` (project creation) and `sim_activate` (project loading).

## Analogies

- `sim_init` ~ `git init` — "this directory is my project root"
- `sim_activate` ~ `Pkg.activate` — "prepare this project for work"

## Decisions

**Q**: What does `sim_init` do?
**A**: Creates `.simuleos/project.json` with `{"id": "<uuid4>"}`. This is the **only** place in the entire system that creates `project.json`. The `.simuleos/` directory marks the project root; this decision propagates to later processes by checking for it.

**Q**: What does `sim_init` create inside `.simuleos/`?
**A**: `.simuleos/project.json` with a random UUID (`UUIDs.uuid4()` from stdlib). No other files or subdirs at init time.

**Q**: Should `sim_init` also activate?
**A**: Yes. `sim_init` initializes then calls `sim_activate` internally.

**Q**: Idempotency — what if `.simuleos/project.json` already exists?
**A**: Preserve existing `project.json` entirely (don't touch it). Still call `sim_activate`.

**Q**: `sim_init` signature?
**A**: `sim_init()` defaults to `pwd()`, `sim_init(path)` for explicit path. Accepts `args` kwarg: `sim_init(path; args=Dict{String,Any}())`.

**Q**: Should `sim_init` log on success?
**A**: Yes. `@info "Simuleos project initialized at $path"` on fresh init, `@info "Project already initialized, activating..."` on re-init.

**Q**: Where does `sim_init` live?
**A**: New file `src/Core/sys-init.jl`. Init is a system-level concern, not OS-level.

**Q**: Should `sim_activate` validate project folder integrity?
**A**: Yes. New function `validate_project_folder(path)` checks `.simuleos/project.json` exists. Called by `sim_activate`. Errors with guidance to run `sim_init` if missing.

**Q**: Should `project.json` feed into the `Project` type?
**A**: Yes. Add `id::String` to `Project`, loaded from `project.json` at `project()` initialization time.

**Q**: Does `sim_activate` keep upward directory search?
**A**: Yes. The no-arg `sim_activate()` walks up from `pwd()` looking for `.simuleos/`.

## Summary of Changes

| File | Change |
|---|---|
| `src/Core/sys-init.jl` | **New**. `sim_init()`, `sim_init(path; args)`. Creates `.simuleos/project.json`, calls `sim_activate`. |
| `src/Core/OS.jl` | Remove `.simuleos/` directory creation logic from `sim_activate`. Add call to `validate_project_folder`. |
| `src/Core/types.jl` | Add `id::String` field to `Project`. |
| `src/Core/OS.jl` (`project()`) | Load `id` from `project.json` when constructing `Project`. |
| `src/Core/home.jl` | Add `project_json_path(project_root)` helper. |
| `src/Core/Core.jl` | Include `sys-init.jl`. |

## `project.json` Schema (v1)

```json
{
    "id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
}
```
