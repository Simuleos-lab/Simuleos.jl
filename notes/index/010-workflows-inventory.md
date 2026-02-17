## Workflows List

- here we can list the key workflows that Simuleos should support
- it might describes both existing and planned workflows
- a workflow is a sequence of steps to achieve a specific goal
    - it might involve multiple functionalities and subsystems

### SimuleOs: workflows
- a conceptual description of important functionalities of SimuleOs
- for instance
    - scope recording
    - database reading
    - system management 
        - eg: rm, gc, rename, archive, etc...

### Workflows: Scope Recording
-  Key workflow: embed simuleos macros to capture program scopes into .simuleos database
- Steps: init → session → record scopes (with labels/context) → commit → repeat
- Globals-based interface preferred (macros use implicit current_session)
- `@session_init` resolves session by first label (`labels[1]`) at project level.
- If multiple sessions match first label, select the most recent.
- If no session matches first label, create a new session with a new UUID.
- `@session_init` labels must be strings.


### Workflows: Database reading

- Purpose: read scope-recording data for analysis and downstream computations (including
plotting).
- Prefer functional interfaces with explicit inputs.
    - Example: load_tape(session::Session, tapeid::String, ...).
    - Supports multiple sessions and explicit loading control.
- Draft flow:
    - init SimuleOs
    - load session
    - load tape/scope
    - use data for computation/plotting
    - repeat as needed


### SimuleOs: sim_init
- this is the entry point of the system
- it deal with the minimal global configuration
- for instance
    - scan for a project
    - load settings
    - init key objects
        - like SimOs
- we should keep it simple and light
- we might call it on `using Simuleos` by default
- Users needs to call it at least one explicitly at an empty project
- All workflows must start by this call
    - implicitly or explicitly


### Tape rewrite system
- Goal: rewrite tape data for format changes, bug fixes, or consolidation.
- Consolidation path: collection-optimized -> storage-optimized (inline ->
deduplicated), one target format at a time.
- Invariant: new tape is functionally equivalent (aliases/references preserved).
- Process: read old tape -> process records -> write new tape -> reconstruct temp-old ->
validate against original old tape -> <optional> delete old tape.
