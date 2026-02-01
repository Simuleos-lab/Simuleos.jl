# LiteTapes

LiteTapes is a Julia library built on top of **LiteRecords** and implements the **Tara Tapes** specification in Julia.  
It provides the canonical, append-only, segment-based storage layer used by Tara-compatible tools, including ContextRecorders such as Simuleos.

LiteTapes focuses on a **simple, explicit, and durable** representation of ordered record streams, stored as immutable segments on disk.

---

## Overview

LiteTapes organizes storage into three core levels:

1. **LiteTapeLib**  
   Root directory acting as the storage library.  
   It contains multiple Tape folders and the library meta information.

2. **LiteTape**  
   A folder inside the library representing an append-only ordered sequence of **segments**.  
   Each Tape contains a meta segment and a list of immutable data segments.

3. **LiteTapeSegment**  
   A single immutable file containing a collection of TaraSON records.  
   Segments are stored as `.jsonl` files and are never modified once created.

LiteTapes reuses **LiteRecords** as the in-memory representation of each record’s payload.

---

## Design Features

### 1. Canonical Tape Structure
- A Tape is a folder containing:
  - a **meta segment** describing Tape identity and segment list,
  - an ordered collection of immutable **segment files**.
- Segment files use `.jsonl` to store TaraSON documents line-by-line.
- Segments are discovered through the Tape meta, not by scanning the directory.

### 2. Append-Only Semantics
- New data is added only by **creating new segments** at the end of the Tape.
- Existing segments are **never** modified or deleted.
- This ensures deterministic, reproducible, content-stable storage.

### 3. Disk–RAM Interaction
- Segments are loaded on demand.
- Payloads stored in LiteRecords follow the TaraSON lite-type rules.
- No caching assumptions are made; loading policies belong to the implementation.

### 4. Tape Metadata
- Each Tape has a canonical meta record describing:
  - the Tape’s identity,
  - creation time,
  - format version,
  - the ordered list of segment descriptors.
- Meta is stored as a reserved TaraSON segment (`segment 0`).

### 5. Record Storage
- Each line in a segment is a **TaraSON record**, typically represented in memory as a `LiteRecord`.
- Records are immutable once written to a segment.
- Writers generate new segments; readers operate over existing ones.

---

## Basic Usage Example

```julia
using LiteTapes
using UUIDs

# Create or open a library
lib = LiteTapeLib("/path/to/storage")

# Create a new tape
tape = LiteTape(lib, string(uuid4()))

# Start a new segment writer
writer = LiteTapeSegmentWriter(tape)

# Write LiteRecords as TaraSON lines
rec = LiteRecord(("A" => 1, "B" => "x"))
write!(writer, rec)

# Finalize the segment (makes it immutable and updates tape meta)
close(writer)

# Iterate over all segments and records
for seg in segments(tape)
    for record in seg
        @show record
    end
end
````

---

## Notes

* LiteTapes does **not** define the semantics of the records themselves;
  it only provides the canonical storage substrate.
* ContextRecorders (e.g., Simuleos) build higher-level workflows on top of LiteTapes.
* Tape repacking, compaction, and deduplication can be implemented as separate operations that produce equivalent Tapes without altering the semantics of existing records.
