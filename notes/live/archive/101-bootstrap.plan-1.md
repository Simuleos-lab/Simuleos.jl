**Bootstrap plan (v0 → v1):**

1. **Define the record model (append-only):** Run = metadata + stages; Stage = scopes; Scope = vars + summaries + context pointers.
2. **Decide storage layout:** local folder repo (e.g., `./simuleos/`) with immutable blobs + small JSON index.
3. **Implement the 4 macros minimally:**

   * `@sim_session(label)` starts run + captures context
   * `@sim_store vars...` marks vars for persistence
   * `@sim_capture(label)` captures local scope + links stored vars
   * `@sim_commit()` finalizes + writes manifest
4. **Context capture v0:** script path, git commit hash + dirty flag, Julia version, project/manifest, timestamp, hostname.
5. **Non-invasive guarantee:** if Simuleos isn’t loaded, scripts still run (no-op macros).
6. **Acceptance test:** the `.sim.jl` produces a browsable run folder that fully reproduces parameters + environment fingerprints.

**Next interview question:**
What EXACTLY counts as “context” in your MVP, and what’s the hard line for privacy/size? (Pick must-have fields + nice-to-have fields.)
