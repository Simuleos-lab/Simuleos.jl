# Simuleos Test Infra Bootstrap - Decisions
**Session**: 2026-02-14 17:06 CST

**Issue**: Package tests fail during module initialization because auto-activation runs before test bootstrap; design a minimal, robust test infra with isolated project/home setup.

**Q**: Scope of change?
**A**: Test infra only.

**Q**: How should tests bootstrap project/home?
**A**: Add `test_init` in `test/test-init.jl` that prepares temp folders and calls `Kernel.sim_init(...)`.

**Q**: Should tests use Kernel-level reset/activation APIs?
**A**: Yes. Use `Simuleos.Kernel.reset_sim!()` in test bootstrap and for isolated contexts.

**Q**: Should home-path override come from bootstrap?
**A**: Yes. Use bootstrap key `"homePath"` as canonical.

**Q**: How to isolate home in tests?
**A**: Isolation is done by calling `sim_init(...; bootstrap=Dict("homePath"=>temp_home))` (not by changing `ENV["HOME"]`).

**Q**: How to avoid `__init__` auto-activation during tests?
**A**: Use `ENV["SIMULEOS_TEST_MODE"]="true"` in test harness (already supported in `Simuleos/src/Simuleos.jl`).

**Q**: Bootstrap placement and lifecycle?
**A**: Put bootstrap in `test/test-init.jl`; run one global init for `runtests.jl` plus helper(s) for extra isolated contexts when needed; `cd` into temp project for test execution; cleanup temp dirs at end.

**Q**: Fixture specifics right now?
**A**: Keep minimal infra and use common sense per test; evolve fixture content only as required by actual tests.

**Decision**: Build a minimal test harness around `test/test-init.jl` using `SIMULEOS_TEST_MODE`, Kernel reset/init APIs, bootstrap-driven `homePath`, temp project/home setup, global test context plus optional extra isolated contexts, and deterministic cleanup.

**Implementation Plan**
1. Add `test/test-init.jl` with global refs/constants and functions: `test_init!()`, `test_cleanup!()`, and `with_test_context(f)` for extra isolation.
2. In `test_init!()`: call `Simuleos.Kernel.reset_sim!()`, create temp root, prepare temp project folder (copy fixture/skeleton as needed), choose temp home path, `cd` to temp project, call `Simuleos.Kernel.sim_init(temp_project; bootstrap=Dict("homePath"=>temp_home))`.
3. Update `test/runtests.jl` order: set `ENV["SIMULEOS_TEST_MODE"]="true"` before `using Simuleos`; include `test/test-init.jl`; run `test_init!()`; include test files; run `test_cleanup!()` in `finally`.
4. Keep current tests unchanged initially; only migrate individual tests to `with_test_context` when they need isolated state.
5. Validate with `Pkg.test("Simuleos")` and capture remaining failures as test-level issues (not bootstrap issues).
