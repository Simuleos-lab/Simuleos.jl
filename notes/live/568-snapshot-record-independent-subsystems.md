# 568 — Snapshot & Record as Independent Subsystems

**Date:** 2026-02-25
**Status:** Design discussion (refinement of 567)
**Predecessor:** 567-capture-recording-split-design.md
**Scope:** the Capture system and the Recording system as two independent subsystems with a bridge between them

---

## Evolution from 567

Note 567 introduced the capture/recording split. This note goes further: the two are not just separate operations — they are **independent subsystems** with independent designs. Neither is built around the other. They compose through a bridge (serialization/deserialization), but each stands alone.

---

## Subsystem 1: Capture System

### Purpose

Gather computation state from multiple sources into a structured in-memory object.

### Core type: `Snapshot`

A Snapshot is the product of the capture system. It bundles state facets collected from sources at a point in time. It is:

- **Ephemeral** — lives in memory, no persistence guarantee
- **Structured** — organized by facet (settings, source, environment, etc.)
- **Composable** — you can capture one facet or all facets
- **Diffable** — two snapshots can be compared to find what changed
- **Independent** — knows nothing about tapes, records, or persistence

### Sources (pluggable collectors)

Each source knows how to observe one facet of computation state:

| Source | Facet | Output |
|---|---|---|
| Settings collector | Configuration state | keys accessed → values |
| Source collector | Code identity | git hash, dirty flag |
| Environment collector | Runtime platform | Julia version, packages, OS |
| Execution collector | Run identity | script path, hostname, timestamp |
| Scope collector | Julia variables | user-staged blobs, hashes, inlines |
| User collector | Manual annotations | metadata, notes, labels |

### Operations

```
capture(source)      → Snapshot (single facet)
capture(sources...)   → Snapshot (multiple facets merged)
capture()            → Snapshot (all active sources)

diff(snap1, snap2)   → SnapshotDiff (what changed between two snapshots)
merge(snap1, snap2)  → Snapshot (combine facets from two snapshots)
```

### Design boundaries

- The capture system does NOT write to disk, tape, or database.
- The capture system does NOT generate hashes or refs.
- The capture system does NOT know what will happen to the Snapshot after creation.
- A Snapshot is a value — it can be passed around, stored in a variable, compared, discarded.

---

## Subsystem 2: Recording System

### Purpose

Persist structured data as immutable, content-addressed records on append-only tapes.

### Core type: `Record`

A Record is the atom of the recording system. It is:

- **Persistent** — written to tape, immutable once written
- **Content-addressed** — identified by a hash of its content
- **Opaque to content** — a Record can hold anything (a Snapshot, a note, a blob, a metric, arbitrary data)
- **Referenceable** — has a `RecordRef` (full hash + short hash) for lookup
- **Independent** — knows nothing about Snapshots, sources, or the capture system

### Core type: `RecordRef`

A lightweight handle for referring to a Record:

```
RecordRef
  hash::String      # full content hash (collision-resistant)
  short::String     # display-friendly short hash (auto-extends on ambiguity)
```

String interpolation uses the short form: `"result_$(ref).png"` → `"result_a7f3.png"`

### Core type: `Tape`

An append-only, ordered collection of Records.

### Operations

```
record(tape, data)        → RecordRef (serialize data, write to tape, return ref)
resolve(tape, ref)        → data (look up a record, return its content)
tag(tape, ref, label)     → RecordRef (attach a label to a record)
```

### Design boundaries

- The recording system does NOT know what a Snapshot is.
- The recording system does NOT collect state or observe sources.
- The recording system only cares about: serialize, hash, append, lookup.
- A Record's content is opaque — the system stores and retrieves it, it doesn't interpret it.

---

## The Bridge

The capture and recording systems connect through serialization:

```
Capture system              Recording system
──────────────              ────────────────
Sources → Snapshot          Record → Tape
                  \        /
                   bridge
              (serialize / deserialize)
```

### Snapshot → Record (persist a capture)

```julia
snap = capture()               # capture system produces Snapshot
ref  = record(tape, snap)      # recording system persists it, returns ref
```

The bridge serializes the Snapshot into the format the recording system expects. The recording system doesn't know it's a Snapshot — it's just data.

### Record → Snapshot (reconstruct from tape)

```julia
data = resolve(tape, ref)      # recording system retrieves raw data
snap = Snapshot(data)           # capture system reconstructs a Snapshot
```

The bridge deserializes the Record content back into a Snapshot. The capture system doesn't know it came from a tape.

### The bridge is thin

The bridge is just serialization/deserialization. It's not a subsystem — it's a pair of functions that know both types. If either subsystem changes its internal representation, only the bridge adapts.

---

## Workflow examples (revisited)

### Scope recording workflow

```julia
snap = capture()                # all facets
ref  = record(tape, snap)      # persist
tag(tape, ref, "snapshot-1")   # label
# ... more computation ...
snap2 = capture()
ref2  = record(tape, snap2)
tag(tape, ref2, "snapshot-2")
commit(tape, "experiment done") # persistence boundary
```

### Provenance stamp (image naming)

```julia
snap = capture()
ref  = record(tape, snap)
savefig("loss_$(ref).png")     # short hash in filename
# later: resolve(tape, ref) → full state
```

### Inspect without recording

```julia
snap = capture(:settings)      # just settings facet
@show snap                     # inspect in REPL, nothing persisted
```

### Record without capturing

```julia
record(tape, "Switched to optimizer B")   # manual annotation
record(tape, Dict("rmse" => 0.042))       # arbitrary data
```

### Reconstruct from tape

```julia
data = resolve(tape, "a7f3")
snap = Snapshot(data)
diff(snap, current_snap)       # what changed since that record?
```

---

## Design principles (updated)

1. **Two independent subsystems** — capture and recording are designed separately; neither depends on the other
2. **Snapshot is the capture atom** — ephemeral, structured, composable, diffable
3. **Record is the recording atom** — persistent, content-addressed, opaque to content
4. **The bridge is thin** — just serialization between the two worlds
5. **Records hold anything** — a Snapshot, a note, a blob, a metric; the recording system doesn't interpret content
6. **Sources are pluggable** — adding a new state facet means adding a collector, not changing the capture or recording system
