## Public API Surface

- `Simuleos` is the single public export surface.
- Cross-subsystem collaboration should use explicit imports/qualification.
- Do not rely on implicit exports from internal modules.
- New external features should be promoted through `src/Simuleos.jl` only after the interface is stable.
- Default policy: keep new symbols internal unless there is a clear user-layer need.

## System Calls vs Object Manipulation

Simuleos exposes two kinds of user-facing interface, separated by a clear boundary: **system calls** and **object manipulation**.

### System calls (`@simos`)

The `@simos` macro is the system call interface. Any operation that crosses the boundary between the user's Julia process and the Simuleos runtime — reading from or writing to disk, querying tapes, accessing blob storage, managing sessions, configuring settings — is a system call and goes through `@simos`.

The analogy is an operating system: user code does not talk to hardware directly; it issues system calls. `@simos` is that boundary.

This includes:
- **Recording**: session lifecycle, staging, capturing, committing.
- **Querying**: finding scopes, iterating commits, building tables from tape.
- **Hydrating**: resolving blob references into materialized values.
- **Configuring**: settings, SQLite index, cache operations.

### Object manipulation (functions)

Once data has crossed the system boundary and lives in the Julia process as a typed object, the user works with it using normal Julia functions and field access. Inspecting a scope's variable descriptors, reading metadata from a returned struct, filtering a collection of results — these are object operations, not system calls.

### The boundary rule

> **`@simos` = crossing the system boundary (disk, storage, index, engine state).**
> **Functions = operating on objects already in hand.**

A useful test: if the operation could fail because a file is missing, a tape is corrupted, or a blob hash doesn't resolve — it's a system call. If it only depends on data already in memory — it's object manipulation.
