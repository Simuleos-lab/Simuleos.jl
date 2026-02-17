# Integration-Level File Grouping - Decisions

**Issue**: Standardize splitting functions into files by integration level and naming with `-I0x`/`-I1x`/`-I2x`/`-I3x` suffixes.

**Q**: Which integration levels should get their own files?
**A**: Split by actual integration levels present in each logical area; create as many files as there are classifications.

**Q**: How should mixed-level files be handled (e.g., `pipeline.jl` with I0x + I1x)?
**A**: Split into `pipeline-I0x.jl`, `pipeline-I1x.jl`, etc.

**Q**: File suffix format for higher levels?
**A**: Use exact `-I2x` and `-I3x` suffixes.

**Q**: Should includes be updated or compatibility shims added?
**A**: Update includes and references; no compatibility shims.

**Q**: Include order in module entrypoints?
**A**: Preserve existing logical order, but within each logical area order files by I-level from `I0x` → `I3x`.

**Decision**: Split files by integration level, name with `-I0x`/`-I1x`/`-I2x`/`-I3x`, update includes/references without compatibility layers, and order per logical area from low to high integration.

---

# Prompt: Integration-Level File Grouping

Use this prompt to apply the refactor to any module or folder.

```
Goal
- Group functions into files based on integration level (I0x/I1x/I2x/I3x).
- Rename files to include an informative `-I?x` suffix.
- If a file mixes levels, split into multiple files (one per level).

Rules
- Use exact suffixes: `-I0x`, `-I1x`, `-I2x`, `-I3x`.
- Create as many files as there are integration classifications present.
- Do not keep backward compatibility code (no deprecated files, no aliases, no shim includes).
- Update module entrypoints to include the new files.
- Preserve existing logical grouping, but within each group order includes by I-level from I0x → I3x.
- Keep code clean and simple.
- Use explicit imports and fully qualified names.
- Do not add exports for internal modules; only export from the top-level module if needed.

Procedure
1. Scan files and identify function integration levels (based on arguments and SIMOS/SimOs usage).
2. For each logical area, split functions into new `*-I0x.jl`, `*-I1x.jl`, `*-I2x.jl`, `*-I3x.jl` files as needed.
3. Delete or replace the original mixed-level file.
4. Update includes in module entrypoints to reference the new files in I-level order.
5. Confirm there are no leftover references to old filenames.

Output
- Provide a summary of file splits and updated includes.
- Call out any ambiguous functions that need manual I-level classification.
```
