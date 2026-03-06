## Julia Development Patterns

- This note captures implementation patterns that improve readability and maintainability without changing behavior.

## Comment-Scoped Subsystem Grouping

- Intent: Make large structs easier to read by grouping fields into logical subsystem sections using comments only.
- Use when: A struct has many fields and mixes concerns (lifecycle, staging, configuration, runtime registries, observability, caches).
- Mechanism: Reorder fields into coherent groups and add short subsystem headers as comments directly in the struct definition.
- Hard constraint: Do not add or remove fields as part of this pattern.
- Constructor rule: If field order changes, update positional constructors to preserve exact field-to-argument mapping.
- Non-goal: Do not introduce sub-structs or behavior changes.
- Review trigger: A large struct feels like a grab-bag and invariants are hard to scan.
