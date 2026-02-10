# Report: Subsystem Alignment to Low/High Interfaces

Context
- Source: notes/index/subsystem-arch.md
- Integration axis: notes/index/the-integration-axis.md
- Focus: alignment to the two interface styles (low integration ~I1x and high integration >~I3x)

Summary Table

| Subsystem | Low interface (~I1x) | High interface (>~I3x) | Evidence |
|---|---|---|---|
| ScopeRecorder (Recorder) | Yes | Yes | src/Recorder/pipeline.jl, src/Recorder/settings.jl, src/Recorder/simignore.jl for I1x; src/Recorder/session.jl, src/Recorder/macros.jl for I3x |
| ScopeReader (Reader) | No | Yes | src/Reader/Reader.jl is I3x only |
| Registry | No | No (I0x only) | src/Registry/home.jl is I0x only |
| QueryNav (Kernel) | Yes | No (I1x only) | src/Kernel/querynav/handlers.jl, src/Kernel/querynav/loaders.jl |
| BlobStore (Kernel) | No (I0x only) | No | src/Kernel/blobstore/blob.jl |
| TapeIO (Kernel) | No (I0x only) | No | src/Kernel/tapeio/json.jl |
| GitMeta (Kernel) | No (I0x only) | No | src/Kernel/gitmeta/git.jl |

Alignment Notes
- ScopeRecorder is aligned with the two-interface pattern: it has I1x functions (explicit dependencies) and I3x functions (SIMOS-resolving entrypoints).
- ScopeReader is missing the low interface: only an I3x _get_reader() exists in src/Reader/Reader.jl.
- Registry does not align with the two-interface pattern: it is entirely I0x in src/Registry/home.jl and has no I3x entrypoints.
- Kernel subsystems are intentionally low-integration (I0x/I1x) per notes/index/subsystem-arch.md, so absence of I3x there is consistent with the architecture. The two-interface expectation appears to be aimed at App subsystems.
