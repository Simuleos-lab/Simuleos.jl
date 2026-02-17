# proj_init!(simos) Design — Decisions
**Session**: 2026-02-15

**Issue**: Implement `proj_init!(simos)` as the project initialization step in `sim_init!`, using UX settings bootstrapping instead of positional arguments.

**Q**: Where does `projRoot` come from if not in bootstrap?
**A**: Default to `pwd()` if `settings(simos, "projRoot", missing)` returns `missing`.

**Q**: What is the resolution/init split?
**A**: Two distinct steps:
1. `resolve_project(simos, proj_root)::SimuleosProject` — pure resolution. Reads disk state, builds the object. If no `.simuleos/project.json` exists, creates an in-memory `SimuleosProject` with a fresh UUID. No disk writes. Calls `_load_project` for the "exists on disk" branch.
2. `proj_init!(simos)` — the mutating step. Calls `resolve_project` internally, sets `simos.project`, then touches disk (creates `.simuleos/`, writes `project.json` if missing).

**Q**: Where does `resolve_project` live?
**A**: In `project-I0x.jl`, alongside existing path helpers. `_load_project` kept as internal helper.

**Q**: Does `resolve_project` handle path normalization?
**A**: No — caller is responsible for passing a clean path.

**Q**: Where does `proj_init!(simos)` live?
**A**: In `project-I1x.jl`. The old `proj_init!(proj::SimuleosProject)` overload is dropped and merged into `proj_init!(simos)`.

**Q**: Should `project-I0x.jl` be reconnected?
**A**: Yes — it has pure path helpers needed by `resolve_project` and constructors.

**Decision**: `proj_init!(simos)` in `project-I1x.jl` reads `projRoot` from UX settings (defaulting to `pwd()`), calls `resolve_project(simos, proj_root)` from `project-I0x.jl` to build or load the `SimuleosProject`, sets `simos.project`, then writes `.simuleos/project.json` to disk if it doesn't exist. `project-I0x.jl` is reconnected in `Kernel.jl`. The old `proj_init!(proj::SimuleosProject)` overload is replaced.
