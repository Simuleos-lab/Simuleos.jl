# Simuleos Usage-Pattern Mining Skill - Decisions

**Issue**: Define a reusable skill for periodic read-only mining of real simulation repositories to detect pressure points and produce Simuleos design-oriented usage-pattern findings.

**Q**: What is the main goal of the workflow?
**A**: Mine real simulation code repeatedly to identify pressure points and derive Simuleos design opportunities (what Simuleos should aid), not to implement solutions.

**Q**: What is the scan scope?
**A**: Scan all repositories under `Simulations/*` by default, using full-repo scanning. The user can optionally focus a run on a specific repo.

**Q**: Should the scan be read-only?
**A**: Yes. The scan is strictly read-only. The user manually updates `Simuleos/notes/live/USAGE.md`.

**Q**: Should the scanner include deprecated/generated sections by default?
**A**: Include everything by default in simulation repos (full-repo scan).

**Q**: What Simuleos context must be loaded before scanning?
**A**: Read all files under `Simuleos/notes/index/*.md`, and include Simuleos code awareness via `Simuleos/src/**` plus `Simuleos/test/**`.

**Q**: Which pressure-point classes are in scope for v1?
**A**: Include all initial classes:
1. Boilerplate repetition.
2. Orchestration friction.
3. State/data capture friction.
4. Reproducibility gaps.
5. Analysis/output friction.
And keep this class list as a skill-internal SSOT section so it can be extended later.

**Q**: What evidence threshold is needed to report a design opportunity?
**A**: A single strong example is enough for reporting in a run.

**Q**: How should findings be ranked and reported?
**A**: Rank candidates internally by `impact + Simuleos-gap + confidence`, select top 3, and output three separate usage-pattern blocks. Do not expose numeric scores/rank in final reported blocks.

**Q**: What output style should be used?
**A**: Direct, structured Markdown sections (not prose-heavy), with style pattern embedded directly in the skill instructions (do not require external style-note references during normal runs).

**Q**: Should findings include implementation/API design proposals?
**A**: No implementation proposals in this skill. Report workflow-level opportunities and frame them as: what users are doing in simulations that Simuleos should aid.

**Q**: How should repeated runs behave?
**A**: Default mode is full rescan. Runs are iterative in the same session; session context and user feedback guide later scans.

**Q**: Should follow-up questions be asked after each run?
**A**: Yes. Ask 2-4 follow-up questions at the end of each run to refine the next scan.

**Decision**: Build a read-only, repeatable usage-pattern mining skill that scans full `Simulations/*` repos (optionally focused per run), cross-checks current Simuleos capabilities (`notes/index/*.md`, `src/**`, `test/**`), ranks candidate findings by `impact + Simuleos-gap + confidence`, and reports exactly three direct, structured usage-pattern blocks per run to support manual curation in `Simuleos/notes/live/USAGE.md`.
