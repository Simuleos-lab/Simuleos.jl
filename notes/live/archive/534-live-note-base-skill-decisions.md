# Live Note Base Skill - Decisions

**Issue**: Define a reusable skill that standardizes live-note location and naming with minimal scope.

**Q**: Where should the skill be installed?
**A**: Global location at `~/.agents/skills/live-note-base/`.

**Q**: What is the canonical live-note filename rule?
**A**: `notes/live/NNN-short-topic.md` with strict consecutive numbering.

**Q**: Is there a required markdown body template for live notes?
**A**: No. The note body format is unconstrained and can be any markdown content.

**Q**: When should this skill be used?
**A**: On demand only, explicitly referenced by other skills when a live note is required.

**Q**: What number format is required for `NNN`?
**A**: Zero-padded 3-digit prefixes.

**Q**: Which files are considered when calculating the current largest prefix?
**A**: Only files matching `notes/live/NNN-*.md`.

**Q**: What helper script is needed?
**A**: A POSIX `sh` batch script that helps the model find the largest existing prefix number.

**Q**: How should numbering handle empty/missing ranges?
**A**: Use `max + 1` policy semantics for progression; the helper reports the current max.

**Q**: What is the reserved numbering rule?
**A**: `000-099` are reserved for direct human management.

**Q**: What should the helper output when no matching files exist?
**A**: Print `100`.

**Q**: Where should the helper script live?
**A**: `~/.agents/skills/live-note-base/scripts/get_max_live_prefix.sh`.

**Decision**: Implement `live-note-base` as a global skill focused strictly on live-note location and naming protocol. Include a POSIX script that prints the largest existing 3-digit prefix from `notes/live/NNN-*.md`, with a minimum baseline output of `100` due to reserved human-managed range `000-099`.
