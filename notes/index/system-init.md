## projPath vd projRoot
Definition
- projPath — input path: any path the caller provides as a starting point (can be a subfolder, a
workspace subdirectory, or the root itself)
- projRoot — resolved root: the actual project root directory, always containing .simuleos/

Key distinction
- projPath preserves caller intent — "where I am"
- projRoot preserves system truth — "where the project lives"
- projPath may equal projRoot, but never the reverse guarantee

 ### Resolve vs Init Convention

- `resolve_*` is the cheap bootstrap function.
- `resolve_*` must only locate/load or minimally construct the driver object.
- `resolve_*` may read existing state (for example from disk) but must avoid side effects.
- `resolve_*` must not write to disk, run validations, or capture metadata.
- `*_init!` is the full readiness function for cold-path setup.
- `*_init!` must call `resolve_*` first, then bind the resolved object into runtime state.
- `*_init!` is responsible for all expensive/side-effect work: persistence, directory creation, metadata capture, and validation guards.
- Naming rule: use `resolve_<entity>` for pure/light resolution and `<entity>_init!` for mutating/full initialization.
- Architectural parallel: this mirrors patterns like `resolve_project` and `proj_init!` to keep lifecycle boundaries explicit.