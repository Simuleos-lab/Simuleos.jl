# Session Folder Structure Refactor - Decisions
**Session**: 2026-02-15

**Issue**: Flip the project folder structure so that sessions are the top-level organizer and scope tapes are subordinate to sessions.

**Q**: Should blobs stay flat at `.simuleos/blobs/` or move under sessions?
**A**: Blobs are a simos-level service, not session-aware. Stay at `.simuleos/blobs/{sha1}.jls`, shared across sessions.

**Q**: Multiple scope tapes per session, or single file?
**A**: Single tape file for now (`context.tape.jsonl`), but use a wrapper `scopetapes/` folder to prepare for future expansion.

**Q**: Session identity model — label string or UUID?
**A**: Sessions get `session_id::UUID` (auto-generated, primary key) + `labels::Vector{String}` (user tags for search). Same pattern as scopes but scopes get labels only, no UUID.

**Q**: Session folder naming on disk?
**A**: Full UUID as folder name under `sessions/`.

**Q**: Scope `label::String` — change to `labels::Vector{String}`?
**A**: Yes, change as part of this refactor.

**Q**: Rename `TAPE_FILENAME` from `context.tape.jsonl`?
**A**: Keep current name.

**Q**: Migration path for old layout (e.g. Lotka-Volterra example)?
**A**: Leave migration for later. Old layouts will break.

**Decision**: Refactor the `.simuleos/` project structure from `tapes/session/...` to `sessions/{uuid}/scopetapes/context.tape.jsonl`. Sessions become the primary organizer with a UUID primary key and user-assigned labels vector. Scopes also move from `label::String` to `labels::Vector{String}`. Blobs remain a shared simos-level service at `.simuleos/blobs/`. No migration utility for now.
