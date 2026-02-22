## Core Design Principles

- Simuleos is both software and experimental instrument.
- Algorithm and refactor changes can change experiment meaning, not only implementation.
- Treat significant behavior changes as experiment variants, not ordinary code churn.
- Keep rigor tiered by cost:
  - always on: preserve intent and change traceability.
  - stabilization: align extracted logic with index constraints.
  - opt-in: full reproducibility pinning when required.
- Human maintains control over when to apply higher-cost rigor workflows.
- Default design target: maximize exploration speed without losing scientific traceability.
- Prefer recording over filtering at capture time.
  - Post-processing and selection can be refined later; lost data cannot.
