# Semantic Class Model for Capture / Write / Read

Date: 2026-02-27

## Why this note

We need a neutral architecture where semantics are preserved across capture, write, and read. For instance, without making `scope` architecturally privileged.

The order of operations is implementation detail; semantic identity must stay stable.

## Core concept

Use **semantic class** as the identity of captured data molecules.

- `class id`: what the thing is semantically (for example `snap.scope`)
- `instance`: one concrete payload of that class
- `representation`: in-memory object, JSON/tape row, SQL row, etc.
- `transforms`: capture, compose, encode, append, read, decode, project

Key rule: class identity is source-of-observation/composition based, not struct-shape based.

Additional rule: Simuleos class identity is language-agnostic SSOT; Julia/Python/etc.
may use different internal representations while respecting the same class semantics.

## Atomic source classes (`src.*`)

- `src.codebase`: repository/source-control state snapshot
- `src.runtime_host`: host/process/runtime environment snapshot
- `src.execution_site`: where/when capture happened (file, line, thread, timestamp)
- `src.namespace_bindings`: visible variable bindings in a namespace window
- `src.settings_access`: resolved settings touched in a capture window
- `src.session_state`: session identity/lifecycle metadata snapshot

## Composed snapshot classes (`snap.*`)

- `snap.scope`: `src.namespace_bindings` + `src.execution_site` + capture labels/metadata
- `snap.context`: `src.settings_access` + `src.codebase` + `src.runtime_host` + `src.execution_site` + `src.session_state`
- `snap.shared`: `src.namespace_bindings` + `src.execution_site` + shared-key identity

## Record/envelope classes (`rec.*`)

- `rec.capture_commit`: append-only batch of `snap.scope` instances + commit metadata
- `rec.ref`: content-addressed envelope that stores one semantic payload by ref

## Current capture loops in this model

- Session bootstrap loop: emits baseline `src.codebase` and `src.runtime_host` for active session state.
- Scope accumulation loop: emits `snap.scope` instances into in-memory stage.
- Scope commit loop: flushes staged `snap.scope` into `rec.capture_commit` on tape.
- Settings-access loop: emits `src.settings_access` windows.
- Context-by-ref loop: composes `snap.context` and writes it via `rec.ref`.
- Shared runtime loop: emits `snap.shared` into in-memory shared registry.

## Architectural constraints

- `scope` is not privileged by architecture; it is one semantic class family among others.
- Every capture class must have matching read/rehydration entrypoints keyed by the same `class id`.
- Payload structure is free and can evolve per subject; semantic class id is the stable contract.
- SQLite index (when used) indexes/project by class ids and reuses kernel rehydration logic.

## Julia implementation profile

- Keep persisted class contract as runtime values (for example `snap.context@v1`).
- In Julia internals, use parametric class tags for dispatch/tooling ergonomics.
- Provide constructor parsing, for example `SimuleosClass("snap.context@v1")`, so call sites do not deal with `Symbol` details.
- Dispatch rule:
  - persistence/protocol boundaries dispatch by runtime `class id + version`
  - in-memory optimized paths may dispatch by parametric class tags mapped from that runtime contract.

## Practical direction

- Add class-id SSOT registry in Kernel.
- Ensure writers stamp class ids.
- Build reader dispatch by class id (agnostic scan + semantic rehydration).
- Keep query/index as optional acceleration layer over same semantic classes.
