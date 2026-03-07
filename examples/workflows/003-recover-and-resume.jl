# ============================================================
# 003 — Recover + Resume from latest scope
# ============================================================

import Simuleos: project, latest_scope, @simos

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
@simos rec.inline(state)

let
    state = [1.0, 0.5]
    energy = sum(abs, state)

    for step in 1:4
        state .+= 0.2
        energy = sum(abs, state)
        global checkpoint_note = "attempt-1-step-$(step)"

        @simos rec.meta(step = step, phase = "attempt-1")
        @simos rec.capture("checkpoint")
    end

    @simos rec.commit("attempt-1-partial")
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

    @simos base.bind(seed_scope, state, energy, step, checkpoint_note)

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
@simos rec.inline(state)

let
    state = [0.0, 0.0]
    energy = 0.0
    step = 0

    @simos base.bind(seed_scope, state, energy, step)

    for resume_step in (step + 1):(step + 3)
        state .+= 0.2
        energy = sum(abs, state)
        global checkpoint_note = "attempt-2-step-$(resume_step)"

        @simos rec.meta(step = resume_step, phase = "attempt-2")
        @simos rec.capture("checkpoint-resume")
    end

    result = @simos session.close("attempt-2-complete")
    println("\nattempt-2 finalize.queued_tail_commit = ", result.queued_tail_commit)
end

# 4) Verify recovery lineage via SQLite
@simos sqlite.open(; sync = :refresh)

println("\n== Recovery Lineage (sqlite) ==")
for row in @simos sqlite.execute("""
    SELECT vs.session_labels_csv, c.commit_label, c.commit_ord,
           COUNT(sc.scope_uid) AS scope_count
    FROM commits c
    JOIN v_sessions vs ON c.session_id = vs.session_id
    LEFT JOIN scopes sc ON c.commit_uid = sc.commit_uid
    JOIN session_labels sl ON c.session_id = sl.session_id
    WHERE sl.label = 'recovery-demo'
    GROUP BY c.commit_uid
    ORDER BY vs.session_labels_csv, c.commit_ord
""")
    println("  [", row[:session_labels_csv], "] #", row[:commit_ord],
        " ", row[:commit_label], " (", row[:scope_count], " scopes)")
end

println("\n== Scope Trail (sqlite) ==")
for row in @simos sqlite.execute("""
    SELECT vs.session_labels_csv, si.scope_labels_csv, si.commit_label, si.src_line
    FROM v_scope_inventory si
    JOIN v_sessions vs ON si.session_id = vs.session_id
    JOIN session_labels sl ON si.session_id = sl.session_id
    WHERE sl.label = 'recovery-demo'
    ORDER BY vs.session_labels_csv, si.commit_ord, si.scope_ord
""")
    println("  [", row[:session_labels_csv], "] scope=", row[:scope_labels_csv],
        " @ ", row[:commit_label], " line=", row[:src_line])
end

println("\n== Step Metadata Across Attempts (sqlite) ==")
for row in @simos sqlite.execute("""
    SELECT vs.session_labels_csv, m.commit_label, m.value_text AS step
    FROM v_scope_meta_inventory m
    JOIN v_sessions vs ON m.session_id = vs.session_id
    JOIN session_labels sl ON m.session_id = sl.session_id
    WHERE sl.label = 'recovery-demo' AND m.meta_key = 'step'
    ORDER BY vs.session_labels_csv, CAST(m.value_text AS INTEGER)
""")
    println("  [", row[:session_labels_csv], "] ", row[:commit_label], " step=", row[:step])
end

@simos sqlite.close()
@simos system.reset()
println("\nDone.")
