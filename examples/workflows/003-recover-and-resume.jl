# ============================================================
# 003 — Recover + Resume from latest scope
# ============================================================

import Simuleos: project, latest_scope, each_scopes, @simos

const SANDBOX_DIR = joinpath(@__DIR__, "_sandbox", basename(@__FILE__))
const PROJ_DIR = joinpath(SANDBOX_DIR, "proj")

global checkpoint_note = "unset"

println("sandbox = ", SANDBOX_DIR)

# 1) First attempt (interrupted after partial commit)
@simos system.init(; reinit = true, sandbox = (;
    root = joinpath(@__DIR__, "_sandbox", basename(@__FILE__)),
    clean_on_init = true,
    cleanup_on_reset = false,
))
@simos session.init("recovery-demo", "attempt-1")
@simos stage.inline(state)

let
    state = [1.0, 0.5]
    energy = sum(abs, state)

    for step in 1:4
        state .+= 0.2
        energy = sum(abs, state)
        global checkpoint_note = "attempt-1-step-$(step)"

        @simos stage.meta(step = step, phase = "attempt-1")
        @simos scope.capture("checkpoint")
    end

    @simos session.commit("attempt-1-partial")
    println("attempt-1 committed through step 4")
end

# 2) Simulated restart + recovery from latest scope
@simos system.reset()
global checkpoint_note = "stale-before-expand"

proj = project(PROJ_DIR)
seed_scope = latest_scope(proj; session = "recovery-demo", commit_label = "attempt-1-partial")

let
    state = [0.0, 0.0]
    energy = -1.0
    step = 0
    checkpoint_note = "local-shadow-before-expand"

    @simos scope.bind(seed_scope, proj, state, energy, step, checkpoint_note)

    println("\n== Recovered State ==")
    println("locals: step=", step, " energy=", energy, " state=", state)
    println("local shadow checkpoint_note=", checkpoint_note)
    println("global checkpoint_note=", getfield(@__MODULE__, :checkpoint_note))
end

# 3) Resume in a new session, seeded from recovered scope
@simos system.init(; reinit = true, sandbox = (;
    root = joinpath(@__DIR__, "_sandbox", basename(@__FILE__)),
    cleanup_on_reset = false,
))
@simos session.init("recovery-demo", "attempt-2")
@simos stage.inline(state)

let
    state = [0.0, 0.0]
    energy = 0.0
    step = 0

    @simos scope.bind(seed_scope, proj, state, energy, step)

    for resume_step in (step + 1):(step + 3)
        state .+= 0.2
        energy = sum(abs, state)
        global checkpoint_note = "attempt-2-step-$(resume_step)"

        @simos stage.meta(step = resume_step, phase = "attempt-2")
        @simos scope.capture("checkpoint-resume")
    end

    result = @simos session.close("attempt-2-complete")
    println("\nattempt-2 finalize.queued_tail_commit = ", result.queued_tail_commit)
end

proj2 = @simos project.current()
scope_count = length(collect(each_scopes(proj2; session = "recovery-demo")))
println("scopes in newest recovery-demo session = ", scope_count)

@simos system.reset()
println("\nDone.")
