# Simuleos Usage Pattern Mining: Findings from Real Simulations

## Case Study: WarburgCellGrid_2024

Analyzed the `WarburgCellGrid_2024` repository, specifically the `scripts/UDynamics` workflow. Identified several patterns that represent "pressure points" in traditional scientific computing workflows, which Simuleos is designed to alleviate.

### 1. Numbered Script Orchestration
**Observed Pattern:**
Users manually order execution via filenames (`1.0_mf.dev.jl`, `2.0_dyn.dev.jl`, `2.2_dyn.time_serie.jl`).

**Pressure Point:**
Dependencies are implicit and fragile. No guarantee that `1.0` was run before `2.2`, or that they used compatible parameters.

**Simuleos Opportunity:**
Formalize this with **Pipeline Definitions**. Explicitly track dependencies between stages (as seen in `examples/workflows/005-pipeline-stage-lineage.jl`).

### 2. Global State for Context Sharing
**Observed Pattern:**
Scripts use `global` variables inside `let` blocks to persist data (e.g., `_Upf_av`) for subsequent plotting blocks within the same file.

**Pressure Point:**
State is fragile and invisible to the provenance system. Re-running a plot requires re-running the heavy computation or hoping the REPL state is correct.

**Simuleos Opportunity:**
Use the **Session** object as the shared context. Computation steps commit results to the session; plotting steps read from the session. This decouples compute from analysis.

### 3. Manual Parameter Sweeps
**Observed Pattern:**
Nested `for` loops with manual index management (`λi, Γi`) to populate pre-allocated result matrices.

**Pressure Point:**
Boilerplate code that mixes orchestration with logic. No fault tolerance (a crash at 99% means total data loss). Hard to parallelize or extend.

**Simuleos Opportunity:**
Introduce **Job/Sweep Abstractions**. "Run this simulation for every combination of these parameters". Automatic result aggregation and checkpointing per iteration.

### 4. Hardcoded Artifact Paths
**Observed Pattern:**
`joinpath(@__DIR__, "plots", filename)`.

**Pressure Point:**
Overwrites previous results. No history. No metadata linking the plot to the parameters or code version that generated it.

**Simuleos Opportunity:**
Automatic **Artifact Management**. `session.save_artifact("plot.png")` which versions the file, stores it in the session sandbox, and links it to the commit.

### 5. In-Memory Big Data
**Observed Pattern:**
`run_dynamic` allocates and returns a large object with full time series (`zeros(n_iters)`).

**Pressure Point:**
Memory bound. Scaling `N` or `n_iters` risks Out-Of-Memory (OOM) errors.

**Simuleos Opportunity:**
**Streaming Results** or periodic checkpointing to disk (Simuleos `Tape`). Allow the simulation to emit data incrementally, keeping memory usage constant.
