## Workflows that preserve experiment history. Each has a tier based on cost.

### Tier 1 — always on
- intent breadcrumbs: agent writes live notes after exploration (what, why, outcome)
    - skill: `live-note-base`
    - skill: `session-what-are-we-doing-report`
- structured commits: descriptive conventional commits at natural breakpoints
    - skill: `git-commit-trigger`

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