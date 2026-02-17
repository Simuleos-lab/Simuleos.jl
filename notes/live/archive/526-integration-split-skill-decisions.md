# Integration-Split Skill - Decisions

**Issue**: Create a local Claude Code skill for applying integration-level file grouping refactor to SimuleOs modules.

**Q**: Skill name and invocation command?
**A**: `/integration-split` (descriptive and clear)

**Q**: Should the skill accept arguments for the target module?
**A**: No arguments — skill asks user interactively which module/folder to process

**Q**: Should Claude auto-invoke the skill when detecting refactor needs?
**A**: No — manual-only invocation (`disable-model-invocation: true`)

**Q**: How should the I Axis reference documentation be provided?
**A**: Referenced at runtime — skill reads `notes/index/the-integration-axis.md` when invoked

**Q**: Target discovery behavior when no arguments provided?
**A**: Ask the user interactively which module/folder to process (e.g., "src/Recorder", "src/Kernel/scopenav")

**Q**: Analysis depth — what operations should the skill perform?
**A**: Rename pure files (e.g., `blob.jl` → `blob-I0x.jl`) + split mixed-level files (e.g., `loaders.jl` → `loaders-I0x.jl` + `loaders-I1x.jl`)

**Q**: Confirmation before executing changes?
**A**: Show full plan with all renames/splits/updates, then ask for approval before execution

**Q**: How should module include statements be updated?
**A**: Clean up and standardize include blocks (consistent spacing, I-level ordering)

**Q**: Handling ambiguous functions (unclear integration level)?
**A**: Skip and report in output for manual classification — don't halt or guess

**Q**: Files with no functions (types, constants, imports only)?
**A**: Classify as I0x by default

**Q**: Summary output format after execution?
**A**: Terminal summary only (no markdown report file)

**Q**: Supporting files in skill directory?
**A**: Just `SKILL.md` (all instructions in one file)

**Decision**: Created `/integration-split` skill at `.claude/skills/integration-split/SKILL.md` with:
- Manual-only invocation
- Interactive target selection
- Full rename + split capability
- Plan review before execution
- Standardized include updates
- Ambiguous function reporting
- Terminal-only output

**Usage**: Run `/integration-split` in Claude Code, specify target module when prompted, review plan, approve execution.
