# Index Drift Review — 554

Date: 2026-02-17

## 1. resolve_project has side effects (violates resolve_* convention)

- **Invariant**: Resolve vs Init Convention (007-system-init)
- **File**: `src/Kernel/core/project-I2x.jl:23`
- `resolve_project(simos::SimOs)` calls `UXLayers.update_bootstrap!`, which mutates state.
  The index states resolve_* "must avoid side effects" and "must not write to disk, run
  validations, or capture metadata." The docstring itself acknowledges "writes bootstrap."

## 2. blob_write in I0x file performs disk I/O

- **Invariant**: Integration Axis File Naming Convention (009-the-integration-axis)
- **File**: `src/Kernel/blobstorage/blob-I0x.jl:46,61-62`
- `blob_write` calls `mkpath` and `open(..., "w")` to create directories and write files.
  I0x files should be "pure utilities, no SimOs integration." While blob_write doesn't
  use SimOs, performing disk writes is not pure. The read functions in the same file are
  fine; the write function should be split out or the file reclassified.

## 3. session_init! writes simos.worksession in an I1x file

- **Invariant**: Integration Axis Levels (009-the-integration-axis)
- **File**: `src/WorkSession/session-I1x.jl:219`
- `session_init!(simos, proj; ...)` mutates `simos.worksession = worksession`. Throughout
  the codebase, dot-field mutation on SimOs is classified as I2x behavior (see home-I2x.jl,
  project-I2x.jl). The function's own docstring says I1x but notes "writes simos.worksession."

## 4. isdirty takes explicit SimOs arg in I3x file

- **Invariant**: Integration Axis Levels (009-the-integration-axis)
- **File**: `src/WorkSession/session-I3x.jl:20-24`
- `isdirty(simos::Kernel.SimOs, worksession::Kernel.WorkSession)` dispatches on explicit
  typed SimOs, but the arg is immediately discarded (`_ = simos`). I3x functions should
  resolve globals internally. Either drop the arg or move the method to a lower-I file.

## 5. settings dispatches on explicit WorkSession in I3x file

- **Invariant**: Integration Axis Levels (009-the-integration-axis)
- **File**: `src/WorkSession/settings-I3x.jl:14,47`
- `settings(worksession::Kernel.WorkSession, key)` takes an explicit subsystem object
  (I1x-style dispatch) but internally calls `Kernel._get_sim()` (I3x access). The mixed
  level is defensible but inconsistent with the naming convention's intent.

---

No prior drift review reports found for comparison.
