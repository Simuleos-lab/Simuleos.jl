# Simuleos Bootstrap Design (MVP)

This document captures the **design decisions and execution workflow** for the Simuleos bootstrap phase, grounded explicitly in the example scripts:

* `scripts/Lotka–Volterra-main.raw.jl`
* `scripts/Lotka–Volterra-main.sim.jl`

The goal is to define a **minimal, coherent, non-invasive system** that reproduces the behavior demonstrated in these scripts while establishing solid conceptual foundations (context, scope, stages, append-only records).

---

## 1. Core Goal

Simuleos is an *operative system for simulations*.

Its purpose is **not** to change how users write simulation code, but to:

* Capture **what happened** during a simulation
* Preserve **results + parameters + environment**
* Do so **implicitly**, by observing Julia scope
* Store everything in an **append-only**, auditable way

The system prioritizes *understandability* and *reproducibility* over performance or minimal storage.

This document focuses on the **capturing phase** only. Retrieval, browsing, and analysis tools are explicitly out of scope for the MVP.

---

## 2. Guiding Principles

### 2.1 Non-invasive by design

* Simulation code remains valid Julia.
* Using Simuleos must not require refactoring algorithms.

### 2.2 Scope is the interface

* **Julia scope is the primary interface** between user and Simuleos.
* This minimizes boilerplate and explicit metadata construction.

For example, instead of manually assembling a parameter dictionary:

```julia
params = Dict(
    "X0"=>X0, "Y0"=>Y0, "α"=>α, "β"=>β, "δ"=>δ, "γ"=>γ,
    "σx"=>σx, "σy"=>σy, "dt"=>dt, "T"=>T, "seed"=>seed,
    "intervention"=>string(intervention), "strength"=>strength, "t_int"=>t_int
)
```

Simuleos simply inspects the scope directly.

> "If you want Simuleos to know about it, put it in scope."

---

## 3. High-Level Workflow (as in the Examples)

The `.sim.jl` script introduces a **session → work → capture → commit** workflow layered on top of standard Julia code.

### Typical flow (Lotka–Volterra example)

1. Start a simulation session (Simuleos)
2. Define parameters and models (Julia)
3. Run simulation logic (Julia)
4. Capture scope snapshots at key moments (Simuleos)
5. Commit accumulated captures as a stage (Simuleos)

This structure is explicit but **lightweight**.

---

## 4. Session

### `@sim_session label`

* Declares a **run label**
* Initializes global Simuleos state
* Clears any existing stage data

A `@sim_session` call adds a global label.
This label will be present on all commits made under this session.

---

## 5. Stages

A **stage** is a stack of captured scopes and run metadata accumulated between commits.

### Properties

* A stage accumulates multiple scope captures
* A stage is **cleared by** 
    * `@sim_commit`
    * `@sim_session` (session start)

Stages are append-only: once committed, never modified.

### Rationale

Stages correspond naturally to:

* Phases of a simulation
* Iterative experiments
* Parameter sweeps

---

## 6. Capture

### `@sim_capture label`

This is the **core operation** of Simuleos.

When called:

1. The **current Julia local scope** is snapshotted
2. A `Scope` object is created
3. The scope is pushed onto the **current stage stack** plus some metadata

No persistent metadata is written at this point, except for explicitly requested blobs.

---

## 7. Scope Model

### Scope

A `Scope` is a dictionary-like object:

* Keys: variable names (strings)
* Values: structured descriptions of variables

Every `@sim_capture` produces exactly one `Scope`.

---

## 8. ScopeVariable

Each variable in scope becomes a `ScopeVariable`.

### Always stored (for all variables)

* `name`
* `type` (short string)
    * the type is for documentation only, not for reconstruction

### Conditionally stored

* `value` → **only if lite**
* `blob_ref` → **only if explicitly requested**

---

## 9. Lite vs Non-Lite Data

### Lite data (MVP definition)

Only **JSON-primitive equivalents**:

* `Bool`
* `Int`, `Float`
* `String`
* `nothing`, `missing`

Lite values are **always inlined** into the JSON context.

### Non-lite data

Examples:

* Arrays
* Matrices
* Structs
* Functions

For these:

* A **descriptor is always stored**
* The actual value is **not stored by default**

---

## 10. Explicit Storage of Non-Lite Data

### `@sim_store A`

* Does **not** store immediately
* Marks `A` in a global **blob_set**
    * `@sim_capture` cleans the `blob_set` after processing
* Signals intent to persist the value on the next capture

### Blob creation semantics

* Blob is written **at `@sim_capture` time**
* Not at commit time
    * this is useful for long-running scripts
    * it avoid carrying large data in memory until commit    
* The scope receives a `blob_ref`

This ensures:

* Blobs exist even if commit fails
* A future GC can safely prune unlinked blobs

---

## 11. Commit

### `@sim_commit`

* Persists the current stage as a **stage record**
* Writes:

  * Stage metadata
  * Ordered list of captured scopes
  * Links to blobs
* Clears the stage stack

Commits are **append-only**.

Commits append to the session tape.
The tape is the authoritative record of what happened during the session.
It is just a `jsonl` file with one commit record per line.

---

## 12. Append-Only Strategy

* Runs are immutable
* Stages are immutable
* Scopes are immutable
* Blobs are immutable

Corrections or reruns always produce **new records**, never edits.

---

## 14. Summary

The MVP Simuleos workflow:

* Uses **Julia scope as the sole user interface**
* Captures *all lightweight data automatically*
* Requires *minimal signaling* for heavy data
* Structures execution via **session, capture, commit**
* Stores all information in **plain, append-only artifacts**

This specification matches the behavior demonstrated in `Lotka–Volterra-main.sim.jl` and defines a solid foundation for future extensions (litetify, richer context, remote backends, UI tooling).
