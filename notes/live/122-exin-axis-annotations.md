# Integration Axis Annotations - Decisions

**Issue**: Functions lacked doc annotations indicating their position on the integration axis (`the-integration-axis.md`).

**Q**: Should we add annotations to every function documenting its integration level and which objects it uses?
**A**: Yes. Every function gets a succinct `INN — uses ...` line in its docstring or a `# INN` comment.

**Q**: Is mutation relevant to the axis classification?
**A**: No. The axis is about **what objects a function uses** (how it gets its dependencies), not whether it mutates them. A function that writes `SIMOS[].recorder` is still I3x because it resolves the global.

**Q**: What format for the annotations?
**A**: One-line in docstrings: `INN — reads/writes object.path`. For groups of pure functions, a single header comment: `# (all I0x — description)`.

**Decision**: Added integration level annotations to all functions across 15 source files. Classification:
- **I0x** (pure, no SimOs): path helpers, type utils, JSON serialization, git interface, blob hashing, record constructors, simignore validators
- **I1x** (all deps as args): `_fill_scope!`, `write_commit_to_tape`, `_process_var!`, `set_simignore_rules!`, handler navigation/loaders, `_reset_settings_cache!`
- **I2x** (pass SimOs, reach inside): `project(sim)`, `ux_root(sim)`, `settings(sim, key)`, `_buildux!(sim, args)`
- **I3x** (resolve globals): `_get_sim()`, `_get_recorder()`, `_get_reader()`, `sim_activate`, `session_init`, all `@session_*` macros, `session_capture`, `session_commit`, `simignore!`
- **I1x/I3x hybrid**: `settings(recorder, key)` — I1x on cache hit, falls back to I3x on miss
