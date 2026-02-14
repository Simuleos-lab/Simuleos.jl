# Path Interface Drivers Refactor - Decisions
**Session**: 2026-02-13 23:50 CST

**Issue**: Path/interface APIs mix bootstrap string-based functions with runtime driver usage, causing unclear ownership and inconsistent dispatch.

**Q**: Should path helpers keep `String` signatures as bootstrap SSOT while runtime code uses driver-based overloads?
**A**: Yes. `String` path helpers remain bootstrap SSOT; once drivers exist, operational APIs must be driver-based.

**Q**: Should home/project settings path APIs be renamed with no compatibility layer?
**A**: Yes. Rename and remove old names: `global_settings_path` -> `home_settings_path`, `local_settings_path` -> `proj_settings_path`.

**Q**: Should folder validation naming be changed with no compatibility alias?
**A**: Yes. Rename `validate_project_folder` -> `proj_validate_folder` and remove the old symbol.

**Q**: Should project accessors be renamed and old ones removed?
**A**: Yes. Replace `project(sim::SimOs)` and `project()` with `sim_project(sim::SimOs)` and `sim_project()`, removing old methods.

**Q**: How should active project state be managed in `SimOs`?
**A**: Eagerly. `simos.project` is populated during `sim_init`/`sim_activate` (not lazy materialization accessor behavior).

**Q**: What is the `init_home` contract?
**A**: `init_home(home::Kernel.SimuleosHome)` only. Home driver is bootstrapped first via constructor, then initialized; called from `sim_init` if required.

**Q**: Should blob storage migrate fully to a driver object now?
**A**: Yes. Full cutover now to `Kernel.BlobStorage` API style.

**Q**: What shape should blob integration take?
**A**: `Project` owns `blobstorage::Kernel.BlobStorage`; blob ops use `BlobStorage` signatures, and `SimOs` wrappers delegate internally through `simos.project.blobstorage`.

**Decision**: Simuleos will enforce a strict bootstrap-vs-runtime API boundary: bootstrap by `String` SSOT functions only, then transition immediately to explicit driver-based interfaces (`Project`, `SimuleosHome`, `BlobStorage`, `SimOs`). All legacy names and compatibility aliases are removed to keep the surface clean, dispatch-first, and architecture-consistent.
