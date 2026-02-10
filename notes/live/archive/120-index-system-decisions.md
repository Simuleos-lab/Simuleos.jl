# Index Maintenance System - Decisions

**Issue**: Design a general-purpose workflow for maintaining a curated design index alongside any codebase, using specialized review agents.

**Q**: What is the index?
**A**: A curated collection of steering constraints — patterns, decisions, conventions, "not to do" blocks. High-signal, not documentation. As informative as possible, as small as possible.

**Q**: What is an index entry?
**A**: A small markdown section (<30 lines). Files are containers, sections are the unit. Flexibility over rigid structure.

**Q**: What is the friction principle?
**A**: Zero friction from "idea to storage". Dump first, organize later. Organization is a maintenance step, not a prerequisite.

**Q**: Who writes the index?
**A**: The user. Agents discover and report, the user decides and writes. This keeps the human steering the process.

**Q**: What do all reviewers share?
**A**: Team identity, understanding of what the index is, report format, read-only constraint, friction principle, philosophy of constant additive improvement.

**Q**: Where does the shared knowledge live?
**A**: `~/.claude/skills/index-base/FOUNDATION.md` — a shared file that all `index-*` skills reference. Key constraints are also duplicated inline in each skill for robustness.

**Q**: Report format?
**A**: Ephemeral (printed to chat, never saved to file). 3-5 findings, <10 lines each, bullet-point structured text with meaningful indentation. H2 for report title, H3 per finding, bold for subsections.

**Q**: Autonomous vs. interactive?
**A**: Separate skills. `index-foo` is autonomous, `index-foo-interview` is interactive.

**Q**: Where do reviewers find the index?
**A**: Project's `AGENTS.md` declares index location.

**Q**: Where do skills live?
**A**: Global `~/.claude/skills/index-*`. Available across all projects.

**Q**: Naming convention?
**A**: All prefixed `index-`. Foundation at `index-base/`.

**Decision**: Build `~/.claude/skills/index-base/FOUNDATION.md` first as the shared knowledge file. Individual reviewer skills (e.g., `index-ssot-check`) come later, each referencing the foundation and duplicating key constraints inline.
