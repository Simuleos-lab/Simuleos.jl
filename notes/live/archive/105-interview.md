# Directory Creation Timing - Decisions

**Issue**: `@sim_session` creates directories at initialization, should defer to write time.

**Q**: When should directories be created?
**A**: On-demand at write time. Create whatever is necessary when writing data.

**Q**: Should `@sim_session` behavior change?
**A**: Keep all current initialization (global state, metadata capture), only defer directory creation.

**Q**: What if write fails due to missing directories?
**A**: Writing operations should silently create parent directories as needed.

**Q**: What happens if `@sim_capture` is called without `@sim_session`?
**A**: Current behavior is correct: throws `"No active Simuleos session. Use @sim_session first."` Keep this.

**Q**: Should sessions persist on disk for recovery across Julia restarts?
**A**: No. Session tracking is purely in-memory for now. All sessions are fresh.

**Q**: Should we support loading sessions from filesystem?
**A**: Not now. That's part of retrieval system design, not recording. Current focus is recording only.

**Decision**: `@sim_session` still required before any captures, just defers directory creation until first write (`@sim_commit` or blob serialization).
