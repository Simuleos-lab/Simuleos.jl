# Project/Home Bootstrap Activation - Decisions
**Session**: 2026-02-14

**Issue**: Finalize and propagate the uncommitted refactor for bootstrap path helpers, project/home drivers, and activation/init APIs.

**Q**: Should String bootstrap path helpers remain public or internal?
**A**: Keep bootstrap String-path helpers internal and underscore-prefixed.

**Q**: What should be the SimOs source of truth for home/project data after activation?
**A**: Bootstrap data is only for `sim_init`/`sim_activate`; after activation the source of truth is driver data (`sim.project`, `sim.home`).

**Q**: How should project driver initialization work?
**A**: `Project` should be partially instantiable first; `proj_init!` completes initialization.

**Q**: Should activation API switch from `args` to `bootstrap`?
**A**: Yes. Use `sim_activate(proj_path, bootstrap)` and propagate the rename.

**Q**: Should `sim_init` keep generic `path` naming?
**A**: No. Use explicit `sim_init(proj_path; bootstrap=...)`.

**Q**: How should settings naming be handled?
**A**: `settings_path` is acceptable when object type is explicit. On SimOs APIs keep explicit wrappers (`proj_settings_path(sim)`, `home_settings_path(sim)`).

**Q**: Should new split files be wired in Kernel includes?
**A**: Yes. Include `core/fs-I0x.jl` and `core/home-I1x.jl`.

**Decision**: Complete the refactor by enforcing underscore-only internal bootstrap path helpers, making `Project` partially constructible then finalized via `proj_init!`, and propagating explicit bootstrap naming in activation/init (`sim_init(proj_path; bootstrap)`, `sim_activate(proj_path, bootstrap)`). Runtime state must rely on driver objects as SSOT, while SimOs wrappers keep explicit project/home settings method names.
