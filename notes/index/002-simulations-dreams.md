## Motivation

- Scientific simulation code is not only software. It is also an experimental instrument. In this setting, refactoring is not just technical cleanup. It is often a hypothesis change, an operational definition change, or a shift in what the simulation is actually measuring. That means the "exploratory phase" is not a temporary phase before production. It is the dominant mode of work.

- The practical consequence is simple: we should treat algorithm changes as experiment variants, not as ordinary code churn.

## Workflows that preserve experiment history. Each has a tier based on cost.

### Tier 1 — always on
- intent breadcrumbs: agent writes live notes after exploration (what, why, outcome)
    - skill: `live-note-base`
    - skill: `session-what-are-we-doing-report`
- structured commits: descriptive conventional commits at natural breakpoints
    - skill: `git-commit-trigger`
No
### Tier 2 — default at stabilization
- extractability: separate reusable logic from experiment wiring
    - skill: TBD (`stabilize-experiment`)
- index alignment: check code vs index drift
    - skill: `index-drift-review`

### Tier 3 — opt-in
- exact reproducibility: pin environment, data, seeds, deps
    - skill: TBD (`pin-experiment`)

## Principles
- cheap workflows are always on, expensive ones are opt-in
- the master list is this note
- agents execute workflows, human decides when to trigger costly ones