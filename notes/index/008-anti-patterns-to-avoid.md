## Anti-Patterns To Avoid

- Prefer machine-readable contracts (types, tags, structured results) over incidental representations (message text, formatting, string shape).
- If a branch changes behavior, the branch condition must be a stable interface contract.
- Prefer one authoritative helper for parsing/path/schema rules instead of local re-implementations.
- Treat compatibility code as temporary migration code with explicit removal intent.

## Stringly Error Protocols

- Do not parse exception text to drive control flow.
- Error messages are for humans and can change without semantic API intent.
- Use typed exceptions or structured outcomes for expected branches (for example: `stored`, `already_exists`, `race_lost`).
- If a dependency exposes only string errors, isolate parsing in one adapter and normalize immediately.
- Review trigger: `catch` plus `sprint(showerror, err)` plus `occursin(...)`.

## Compatibility Branch Accretion

- Do not keep backward-compat aliases, duplicate keys, or old schema readers by default.
- Dual-format support is allowed only at explicit migration boundaries.
- Prefer one canonical write format and one canonical read path after migration.
- If compatibility must remain temporarily, record removal criteria before merging.

## SSOT Bypass In Leaf Code

- Do not duplicate file-name constants, metadata keys, or parsing rules in CLI/report/helper modules when Kernel already defines them.
- Leaf modules should call the authoritative subsystem helper for canonical parsing and validation.
- Repeated local helpers that mirror Kernel behavior are a refactor signal, not a convenience.
- Review question: if the format changes, how many files must change?
