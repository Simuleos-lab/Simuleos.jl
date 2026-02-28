# `src/` Reordering for Class-Aligned Architecture

Date: 2026-02-28

## Goal

Define a clean `src/` organization that reflects Simuleos semantic classes and subsystem workflows without carrying legacy architecture naming.

## Current Layout (Implemented 2026-02-28)

```text
src/
  Simuleos.jl
  Kernel/
    Foundation/
      types.jl
      state.jl
      utils.jl
    ClassSystem/
      registry.jl
      catalog.jl
      tags.jl
    Infra/
      tapeio/
      blobstorage/
      git/
      project/
      home/
      settings/
    Classes/
      src/
      snap/
      rec/
      decode_dispatch.jl
      encode_dispatch.jl
    Workflows/
      capture/
      sessiontrace/
      contextref/
      sharedstate/
    Kernel.jl
  SQLiteIndex/
  SimosAPI/
  WorkSession/
```

## Folder Definitions (One Sentence Each)

- `src/`: Root source tree where all runtime modules are organized by responsibility boundaries.
- `src/Kernel/`: Internal engine module that owns state, semantic class contracts, infra drivers, and workflow orchestration.
- `src/Kernel/Foundation/`: Fundamental low-level primitives and shared internal data types that other Kernel folders build on.
- `src/Kernel/ClassSystem/`: Semantic class SSOT layer that defines class identity, versioning, and registry metadata.
- `src/Kernel/Infra/`: Record-agnostic infrastructure drivers for persistence, environment interaction, and project/home/settings plumbing.
- `src/Kernel/Infra/tapeio/`: Append-only tape file read/write and generic scan utilities with no semantic payload meaning.
- `src/Kernel/Infra/blobstorage/`: Content-addressed blob persistence and retrieval for non-inline payload storage.
- `src/Kernel/Infra/git/`: Repository metadata and git-facing helper operations used by capture and session workflows.
- `src/Kernel/Infra/project/`: Project path resolution and project-scoped filesystem conventions.
- `src/Kernel/Infra/home/`: Simuleos home directory path conventions and bootstrapping helpers.
- `src/Kernel/Infra/settings/`: Layered settings infrastructure and resolution mechanics independent of semantic class payloads.
- `src/Kernel/Classes/`: Semantic class implementations that own encode/decode/rehydration logic for each class family.
- `src/Kernel/Classes/src/`: Atomic source-observation class implementations (`src.*`) and their class-specific transformations.
- `src/Kernel/Classes/snap/`: Snapshot composition class implementations (`snap.*`) for capture/read semantic objects.
- `src/Kernel/Classes/rec/`: Envelope/record class implementations (`rec.*`) used at tape persistence boundaries.
- `src/Kernel/Workflows/`: Operational flows that compose class behavior over infra primitives for concrete system use cases.
- `src/Kernel/Workflows/capture/`: Capture pipeline that produces semantic class instances from runtime observation.
- `src/Kernel/Workflows/sessiontrace/`: Session trace write/read workflow for commit and scope-like tape lifecycle operations.
- `src/Kernel/Workflows/contextref/`: Context capture and content-addressed reference workflow over generic record envelopes.
- `src/Kernel/Workflows/sharedstate/`: Runtime shared namespace/state workflow for in-memory semantic sharing.
- `src/SQLiteIndex/`: Optional indexing/query acceleration backend that consumes Kernel semantic decode contracts.
- `src/SimosAPI/`: Macro and command-surface layer mapping user verbs to Kernel and adapter operations.
- `src/WorkSession/`: User-facing session control layer that coordinates runtime lifecycle actions over Kernel primitives.

## Boundary Rules to Preserve Clarity

- `Kernel/Infra` must not implement semantic class parsing or class-specific query meaning.
- `Kernel/Classes` is the only place where class encode/decode and class rehydration semantics are defined.
- `Kernel/Workflows` composes `ClassSystem + Classes + Infra` and should not duplicate class logic.
- `SQLiteIndex` must consume Kernel class decode paths instead of implementing parallel semantic parsers.
- Public facades (`SimosAPI`, `WorkSession`) expose workflows and should stay thin.

## Reader Decision Update

- Separate `src/Readers/` module was dropped for now.
- Sessiontrace reader semantics now live in `Kernel/Workflows/sessiontrace/reader.jl` beside sessiontrace write/read workflow code.
- Public API remains top-level through `Simuleos.project`, `Simuleos.latest_scope`, `Simuleos.value`, and `Simuleos.scope_table`, imported from `Kernel`.
