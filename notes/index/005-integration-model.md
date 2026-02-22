## Integration Model

- Interfaces exist on a continuum from explicit dependencies to implicit global context.
- Prefer two interface styles per subsystem when useful:
  - base interface with explicit dependencies for internal composition.
  - user interface with resolved context for ergonomic usage.
- Integration levels are design guidance, not strict dogma.
- Choose the lowest integration level that keeps call sites practical.
- Starting integrated is acceptable; split downward when reuse and testing pressure grows.
- If a function depends on implicit global context, make that dependency explicit in docs.
